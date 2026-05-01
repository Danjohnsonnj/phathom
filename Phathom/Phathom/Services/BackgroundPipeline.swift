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
            let ctx = ModelContext(container)
            var limited = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { item in
                    item.processingStatus == "pending"
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            limited.fetchLimit = 4

            guard let items = try? ctx.fetch(limited) else {
                task.setTaskCompleted(success: false)
                scheduleIngest()
                return
            }

            let webItems = items.filter { $0.contentKind == ContentKind.web.rawValue && $0.originalURL != nil }
            var processed = 0
            for item in webItems.prefix(3) {
                guard !cancelFlag.value, processed < 3 else { break }
                if item.originalURL == nil { continue }

                item.processingStatus = ProcessingStatus.scraping.rawValue
                item.processingDetail = "Fetching article…"
                try? ctx.save()

                do {
                    guard let url = item.originalURL else { continue }
                    let result = try await WebIngestService.scrape(url: url)
                    item.rawText = result.text
                    if let t = result.thumbnailData { item.thumbnailData = t }
                    item.displayHost = result.displayHost
                    item.processingStatus = ProcessingStatus.embedding.rawValue
                    item.processingDetail = "Preparing analysis…"
                    try? ctx.save()
                    processed += 1
                } catch {
                    item.processingStatus = ProcessingStatus.failed.rawValue
                    item.failureReason = error.localizedDescription
                    item.processingDetail = nil
                    try? ctx.save()
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
            let ctx = ModelContext(container)
            var desc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { item in
                    item.processingStatus == "embedding"
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            desc.fetchLimit = 1

            guard let item = try? ctx.fetch(desc).first else {
                task.setTaskCompleted(success: true)
                scheduleAnalyze()
                return
            }

            if cancelFlag.value {
                task.setTaskCompleted(success: false)
                scheduleAnalyze()
                return
            }

            guard let raw = item.rawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                item.processingStatus = ProcessingStatus.failed.rawValue
                item.failureReason = "No article text to analyze."
                try? ctx.save()
                task.setTaskCompleted(success: false)
                scheduleAnalyze()
                return
            }

            let article = String(raw.prefix(12_000))

            do {
                try await session.load(path: modelPath)
                if cancelFlag.value {
                    await session.unload()
                    checkpointAfterCancel(item: item)
                    try? ctx.save()
                    task.setTaskCompleted(success: false)
                    scheduleAnalyze()
                    return
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

                if cancelFlag.value {
                    await session.unload()
                    checkpointAfterCancel(item: item)
                    try? ctx.save()
                    task.setTaskCompleted(success: false)
                    scheduleAnalyze()
                    return
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

                if cancelFlag.value {
                    await session.unload()
                    checkpointAfterCancel(item: item)
                    try? ctx.save()
                    task.setTaskCompleted(success: false)
                    scheduleAnalyze()
                    return
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

                item.indexInSpotlight()

                await session.unload()
                task.setTaskCompleted(success: true)
            } catch {
                await session.unload()
                item.processingStatus = ProcessingStatus.failed.rawValue
                item.failureReason = error.localizedDescription
                try? ctx.save()
                task.setTaskCompleted(success: false)
            }

            scheduleAnalyze()
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
    private let analyzer = LlamaContentAnalyzer()
    private var cancelled = false

    func load(path: String) async throws {
        try await analyzer.loadModel(path: path)
    }

    func unload() async {
        await analyzer.unloadModel()
    }

    func cancelAndUnload() async {
        cancelled = true
        await analyzer.unloadModel()
    }

    func summarize(_ text: String) async throws -> [String] {
        if cancelled { return [] }
        return try await analyzer.generateSummary(articleText: text)
    }

    func tags(_ text: String) async throws -> [String] {
        if cancelled { return [] }
        return try await analyzer.generateTags(articleText: text)
    }

    func extracts(_ text: String) async throws -> [Extract] {
        if cancelled { return [] }
        return try await analyzer.generateExtracts(articleText: text)
    }
}
