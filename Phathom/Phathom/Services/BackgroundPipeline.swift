import BackgroundTasks
import Foundation
import SwiftData

private final class CancelFlagBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var cancelled = false

    nonisolated init() {}

    nonisolated var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            cancelled = newValue
        }
    }
}

private enum SingleAnalyzeOutcome: Sendable {
    case noItemToProcess
    case finished(taskSuccess: Bool)
    case cancelled
}

/// Serializes ingest, analyze, and foreground drains so BG and UI-triggered work never double-process the same item.
private actor PipelineSerialGate {
    static let shared = PipelineSerialGate()

    func perform<R: Sendable>(_ work: @Sendable () async -> R) async -> R {
        await work()
    }
}

enum BackgroundPipeline: Sendable {
    nonisolated(unsafe) private static var containerRef: ModelContainer?

    nonisolated static func register(modelContainer: ModelContainer) {
        containerRef = modelContainer

        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.phathom.ingest", using: nil) { task in
            handleIngest(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.phathom.analyze", using: nil) { task in
            handleAnalyze(task: task as! BGProcessingTask)
        }
    }

    nonisolated static func modelContainerOrNil() -> ModelContainer? {
        containerRef
    }

    nonisolated static func scheduleForegroundDrain() {
        Task(priority: .utility) {
            await PipelineSerialGate.shared.perform {
                await runForegroundDrain()
            }
        }
    }

    nonisolated static func scheduleIngest() {
        Task { @MainActor in
            let request = BGAppRefreshTaskRequest(identifier: "com.phathom.ingest")
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
            try? BGTaskScheduler.shared.submit(request)
        }
    }

    nonisolated static func scheduleAnalyze() {
        Task { @MainActor in
            let request = BGProcessingTaskRequest(identifier: "com.phathom.analyze")
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = false
            try? BGTaskScheduler.shared.submit(request)
        }
    }

    nonisolated static func scheduleAll() {
        scheduleIngest()
        scheduleAnalyze()
    }

    /// After a crash mid-inference, rows can stay in `summarizing` / `tagging` / `scraping` forever because
    /// `processNextEmbeddingItem` only fetches `embedding`. Rewind those so the next drain can finish them.
    nonisolated private static func reviveAbortedPipelineItems(modelContainer: ModelContainer) {
        let ctx = ModelContext(modelContainer)
        let llmStuck = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { item in
                !item.isArchived
                    && (item.processingStatus == "summarizing" || item.processingStatus == "tagging")
            }
        )
        if let items = try? ctx.fetch(llmStuck) {
            for item in items {
                item.processingStatus = ProcessingStatus.embedding.rawValue
                item.processingDetail = "Preparing analysis…"
            }
        }
        let scraping = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { item in
                !item.isArchived && item.processingStatus == "scraping"
            }
        )
        if let items = try? ctx.fetch(scraping) {
            for item in items {
                guard item.contentKind == ContentKind.web.rawValue else { continue }
                if item.rawText != nil {
                    item.processingStatus = ProcessingStatus.embedding.rawValue
                    item.processingDetail = "Preparing analysis…"
                } else {
                    item.processingStatus = ProcessingStatus.pending.rawValue
                    item.processingDetail = "Queued for capture"
                }
            }
        }
        try? ctx.save()
    }

    /// Foreground drain body (call only inside `PipelineSerialGate.shared.perform`).
    nonisolated static func runForegroundDrain() async {
        guard let container = containerRef else { return }

        let purgeCtx = ModelContext(container)
        ArchiveRetention.purgeExpired(in: purgeCtx)

        reviveAbortedPipelineItems(modelContainer: container)

        while true {
            if ThermalMonitor.shouldThrottle {
                scheduleAll()
                return
            }

            let didIngest = await processNextPendingWebItem(modelContainer: container) { false }
            if didIngest {
                scheduleAnalyze()
                continue
            }

            guard let modelPath = ModelManager.selectedModelURL?.path,
                  FileManager.default.isReadableFile(atPath: modelPath) else {
                scheduleAll()
                return
            }

            let session = AnalyzeLlamaSession()
            let outcome = await processNextEmbeddingItem(
                modelContainer: container,
                session: session,
                modelPath: modelPath,
                cancel: { false }
            )

            switch outcome {
            case .noItemToProcess:
                return
            case .cancelled:
                return
            case .finished:
                scheduleAnalyze()
                continue
            }
        }
    }

    nonisolated private static func handleIngest(task: BGAppRefreshTask) {
        guard let container = containerRef else {
            task.setTaskCompleted(success: false)
            return
        }

        if ThermalMonitor.shouldThrottle {
            task.setTaskCompleted(success: false)
            scheduleIngest()
            return
        }

        let cancelFlag = CancelFlagBox()
        task.expirationHandler = {
            cancelFlag.value = true
        }

        Task.detached {
            await PipelineSerialGate.shared.perform {
                let purgeCtx = ModelContext(container)
                ArchiveRetention.purgeExpired(in: purgeCtx)
                reviveAbortedPipelineItems(modelContainer: container)
                var processed = 0
                while !cancelFlag.value, processed < 3 {
                    let did = await processNextPendingWebItem(modelContainer: container) { cancelFlag.value }
                    if !did { break }
                    processed += 1
                }
            }

            task.setTaskCompleted(success: true)
            scheduleIngest()
            scheduleAnalyze()
        }
    }

    nonisolated private static func handleAnalyze(task: BGProcessingTask) {
        guard let container = containerRef else {
            task.setTaskCompleted(success: false)
            return
        }

        if ThermalMonitor.shouldThrottle {
            task.setTaskCompleted(success: false)
            scheduleAnalyze()
            return
        }

        guard let modelPath = ModelManager.selectedModelURL?.path,
              FileManager.default.isReadableFile(atPath: modelPath) else {
            task.setTaskCompleted(success: false)
            scheduleAnalyze()
            return
        }

        let session = AnalyzeLlamaSession()
        let cancelFlag = CancelFlagBox()

        task.expirationHandler = {
            cancelFlag.value = true
            Task { await session.cancelAndUnload() }
        }

        Task.detached {
            let outcome = await PipelineSerialGate.shared.perform {
                reviveAbortedPipelineItems(modelContainer: container)
                return await processNextEmbeddingItem(
                    modelContainer: container,
                    session: session,
                    modelPath: modelPath,
                    cancel: { cancelFlag.value }
                )
            }

            switch outcome {
            case .noItemToProcess:
                task.setTaskCompleted(success: true)
            case .cancelled:
                task.setTaskCompleted(success: false)
            case .finished(let taskSuccess):
                task.setTaskCompleted(success: taskSuccess)
            }

            scheduleAnalyze()
        }
    }

    nonisolated private static func processNextPendingWebItem(
        modelContainer: ModelContainer,
        cancel: @Sendable @escaping () -> Bool
    ) async -> Bool {
        let ctx = ModelContext(modelContainer)
        var desc = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { item in
                !item.isArchived && item.processingStatus == "pending" && item.contentKind == "web"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        desc.fetchLimit = 1

        guard let item = try? ctx.fetch(desc).first,
              item.originalURL != nil else {
            return false
        }

        if cancel() { return false }

        item.processingStatus = ProcessingStatus.scraping.rawValue
        item.processingDetail = "Fetching article…"
        try? ctx.save()

        do {
            guard let url = item.originalURL else { return true }
            let result = try await WebIngestService.scrape(url: url)
            item.rawText = result.text
            if let t = result.thumbnailData { item.thumbnailData = t }
            item.displayHost = result.displayHost
            let hadUserTitle = !(item.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !hadUserTitle {
                if let pt = result.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !pt.isEmpty {
                    item.title = String(pt.prefix(200))
                } else {
                    item.title = nil
                }
            }
            item.processingStatus = ProcessingStatus.embedding.rawValue
            item.processingDetail = "Preparing analysis…"
            try? ctx.save()
        } catch {
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = error.localizedDescription
            item.processingDetail = nil
            try? ctx.save()
        }

        return true
    }

    nonisolated private static func processNextEmbeddingItem(
        modelContainer: ModelContainer,
        session: AnalyzeLlamaSession,
        modelPath: String,
        cancel: @Sendable @escaping () -> Bool
    ) async -> SingleAnalyzeOutcome {
        let ctx = ModelContext(modelContainer)
        var desc = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { item in
                !item.isArchived && item.processingStatus == "embedding"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        desc.fetchLimit = 1

        guard let item = try? ctx.fetch(desc).first else {
            return .noItemToProcess
        }

        let itemID = item.id

        if cancel() {
            return .cancelled
        }

        guard let raw = item.rawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = "No article text to analyze."
            try? ctx.save()
            return .finished(taskSuccess: false)
        }

        let article = String(raw.prefix(12_000))

        do {
            try await session.load(path: modelPath)
            if cancel() {
                await session.unload()
                checkpointAfterCancel(item: item)
                try? ctx.save()
                return .cancelled
            }

            item.processingStatus = ProcessingStatus.summarizing.rawValue
            item.processingDetail = "Generating summary…"
            try? ctx.save()

            let bullets = try await session.summarize(article)
            if bullets.isEmpty {
                item.summaryBullets = nil
            } else {
                item.encodeSummaryBullets(bullets)
            }
            try? ctx.save()

            if cancel() {
                await session.unload()
                checkpointAfterCancel(item: item)
                try? ctx.save()
                return .cancelled
            }

            item.processingStatus = ProcessingStatus.tagging.rawValue
            item.processingDetail = "Auto-tagging…"
            try? ctx.save()

            let tagNames = try await session.tags(article)
            for tagName in tagNames {
                let td = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { $0.name == tagName })
                let existing = try? ctx.fetch(td).first
                let tag = existing ?? Tag(name: tagName)
                if existing == nil { ctx.insert(tag) }
                if !item.tags.contains(where: { $0.name == tag.name }) {
                    item.tags.append(tag)
                }
            }
            try? ctx.save()

            if cancel() {
                await session.unload()
                checkpointAfterCancel(item: item)
                try? ctx.save()
                return .cancelled
            }

            item.processingDetail = "Extracting key information…"
            try? ctx.save()

            let extracts = try await session.extracts(article)
            if extracts.isEmpty {
                item.extracts = nil
            } else {
                item.encodeExtracts(extracts)
            }

            item.processingStatus = ProcessingStatus.completed.rawValue
            item.processingDetail = nil
            item.failureReason = nil
            try? ctx.save()

            let verifyDesc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == itemID }
            )
            if let fresh = try? ctx.fetch(verifyDesc).first,
               !fresh.isArchived,
               fresh.status == .completed {
                fresh.indexInSpotlight()
            }

            await session.unload()
            return .finished(taskSuccess: true)
        } catch {
            await session.unload()
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = error.localizedDescription
            try? ctx.save()
            return .finished(taskSuccess: false)
        }
    }

    nonisolated private static func checkpointAfterCancel(item: ContentItem) {
        if item.rawText != nil {
            item.processingStatus = ProcessingStatus.embedding.rawValue
        } else {
            item.processingStatus = ProcessingStatus.pending.rawValue
        }
        item.processingDetail = "Paused — will resume when resources allow"
    }
}

private actor AnalyzeLlamaSession {
    private var cancelled = false

    func load(path: String) async throws {
        try await SharedLlamaInference.shared.ensureLoaded(path: path)
    }

    func unload() async {
        await SharedLlamaInference.shared.unload()
    }

    func cancelAndUnload() async {
        cancelled = true
        await SharedLlamaInference.shared.unload()
    }

    func summarize(_ text: String) async throws -> [String] {
        if cancelled { return [] }
        return try await SharedLlamaInference.shared.generateSummary(articleText: text)
    }

    func tags(_ text: String) async throws -> [String] {
        if cancelled { return [] }
        return try await SharedLlamaInference.shared.generateTags(articleText: text)
    }

    func extracts(_ text: String) async throws -> [Extract] {
        if cancelled { return [] }
        return try await SharedLlamaInference.shared.generateExtracts(articleText: text)
    }
}
