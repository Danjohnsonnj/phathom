import PhathomCore
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

/// Thrown from inside `SharedLlamaInference.withSession` when the pipeline is cancelled (BG expiration / cooperative cancel).
private struct PipelineLlmCancelled: Error {}

// LLM work is serialized by `SharedLlamaInference`'s `AsyncLock` (`withSession`). The old `PipelineSerialGate` did not
// mutually exclude async work (Swift actor reentrancy). Ingest/analyze BG tasks remain one task each from the system;
// multiple `scheduleForegroundDrain` calls can overlap, but any path that touches the model queues on `withSession`.

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
            await runForegroundDrain()
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
                    && item.contentKind != "media"
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
        let mediaStuck = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { item in
                !item.isArchived
                    && item.contentKind == "media"
                    && (item.processingStatus == "embedding"
                        || item.processingStatus == "summarizing"
                        || item.processingStatus == "tagging")
            }
        )
        if let items = try? ctx.fetch(mediaStuck) {
            for item in items {
                item.processingStatus = ProcessingStatus.completed.rawValue
                item.processingDetail = nil
                item.failureReason = nil
                if (item.mediaDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    item.mediaDescription = ShareCapture.mediaPlaceholderDescription
                }
                item.indexInSpotlight()
            }
        }
        try? ctx.save()
    }

    nonisolated static func runForegroundDrain() async {
        guard let container = containerRef else { return }

        await MainActor.run {
            let purgeCtx = ModelContext(container)
            ArchiveRetention.purgeExpired(in: purgeCtx)
        }

        reviveAbortedPipelineItems(modelContainer: container)

        ModelManager.validateSelection()

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

            guard ModelManager.hasReadableSelection else {
                scheduleAll()
                return
            }

            let outcome = await processNextEmbeddingItem(
                modelContainer: container,
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
            await MainActor.run {
                let purgeCtx = ModelContext(container)
                ArchiveRetention.purgeExpired(in: purgeCtx)
            }
            reviveAbortedPipelineItems(modelContainer: container)
            var processed = 0
            while !cancelFlag.value, processed < 3 {
                let did = await processNextPendingWebItem(modelContainer: container) { cancelFlag.value }
                if !did { break }
                processed += 1
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

        ModelManager.validateSelection()

        guard ModelManager.hasReadableSelection else {
            task.setTaskCompleted(success: false)
            scheduleAnalyze()
            return
        }

        let cancelFlag = CancelFlagBox()

        task.expirationHandler = {
            cancelFlag.value = true
            SharedLlamaInference.signalCancelInFlight()
        }

        Task.detached {
            reviveAbortedPipelineItems(modelContainer: container)
            let outcome = await processNextEmbeddingItem(
                modelContainer: container,
                cancel: { cancelFlag.value }
            )

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

        if !NetworkReachability.hasUsableConnection {
            item.processingStatus = ProcessingStatus.pending.rawValue
            item.processingDetail = "Waiting for network…"
            item.failureReason = nil
            try? ctx.save()
            return false
        }

        item.processingStatus = ProcessingStatus.scraping.rawValue
        item.processingDetail = "Fetching article…"
        try? ctx.save()

        do {
            guard let url = item.originalURL else { return false }
            let scrapeItemID = item.id
            let result = try await PipelineMetrics.time("scrape", itemID: scrapeItemID) {
                try await WebIngestService.scrape(url: url)
            }
            item.rawText = result.text
            if let t = result.thumbnailData { item.thumbnailData = t }
            item.displayHost = result.displayHost
            let trimmedExisting = (item.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let originalHost = item.originalURL?.host?.lowercased() ?? ""
            let priorHost = item.displayHost?.lowercased() ?? ""
            let titleLower = trimmedExisting.lowercased()
            let isAutoHostTitle = !trimmedExisting.isEmpty
                && (titleLower == originalHost || titleLower == priorHost)
            let hadUserTitle = !trimmedExisting.isEmpty && !isAutoHostTitle
            if !hadUserTitle {
                if let st = result.suggestedListTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty {
                    item.title = String(st.prefix(200))
                } else if let pt = result.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !pt.isEmpty {
                    item.title = String(pt.prefix(200))
                } else {
                    item.title = nil
                }
            }
            item.processingStatus = ProcessingStatus.embedding.rawValue
            item.processingDetail = "Preparing analysis…"
            try? ctx.save()
            return true
        } catch WebIngestError.offline {
            item.processingStatus = ProcessingStatus.pending.rawValue
            item.processingDetail = "Waiting for network…"
            item.failureReason = nil
            try? ctx.save()
            // Returning false stops `runForegroundDrain`'s ingest loop from immediately re-fetching the same
            // still-`pending` row (would thrash scraping ↔ pending). `NetworkReachability` + next drain retry.
            return false
        } catch {
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = error.localizedDescription
            item.processingDetail = nil
            try? ctx.save()
            return true
        }
    }

    nonisolated private static func processNextEmbeddingItem(
        modelContainer: ModelContainer,
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

        if item.kind == .media {
            item.processingStatus = ProcessingStatus.completed.rawValue
            item.processingDetail = nil
            item.failureReason = nil
            if (item.mediaDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.mediaDescription = ShareCapture.mediaPlaceholderDescription
            }
            try? ctx.save()
            item.indexInSpotlight()
            return .finished(taskSuccess: true)
        }

        guard let raw = item.rawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = "No article text to analyze."
            try? ctx.save()
            return .finished(taskSuccess: false)
        }

        let article = String(raw.prefix(12_000))

        do {
            try await SharedLlamaInference.shared.withSession(unloadOnExit: true, pipelineItemID: itemID) { session in
                if cancel() {
                    await session.cancelInFlight()
                    checkpointAfterCancel(item: item)
                    try? ctx.save()
                    throw PipelineLlmCancelled()
                }

                item.processingStatus = ProcessingStatus.summarizing.rawValue
                item.processingDetail = "Generating summary…"
                try? ctx.save()

                let bullets = try await PipelineMetrics.time("summarize", itemID: itemID) {
                    try await session.summarize(article)
                }
                if bullets.isEmpty {
                    item.summaryBullets = nil
                } else {
                    item.encodeSummaryBullets(bullets)
                }
                try? ctx.save()

                if cancel() {
                    await session.cancelInFlight()
                    checkpointAfterCancel(item: item)
                    try? ctx.save()
                    throw PipelineLlmCancelled()
                }

                item.processingStatus = ProcessingStatus.tagging.rawValue
                item.processingDetail = "Auto-tagging…"
                try? ctx.save()

                let tagNames = try await PipelineMetrics.time("tags_llm", itemID: itemID) {
                    try await session.tags(article)
                }
                let tagDbStart = Date()
                upsertTagsOnItem(tagNames: tagNames, item: item, context: ctx)
                mergePlatformHashtagTags(item: item, context: ctx)
                PipelineMetrics.logSyncElapsed("tag_db", itemID: itemID, start: tagDbStart)
                try? ctx.save()

                if cancel() {
                    await session.cancelInFlight()
                    checkpointAfterCancel(item: item)
                    try? ctx.save()
                    throw PipelineLlmCancelled()
                }

                item.processingDetail = "Extracting key information…"
                try? ctx.save()

                let extracts = try await PipelineMetrics.time("extracts_llm", itemID: itemID) {
                    try await session.extracts(article)
                }
                if extracts.isEmpty {
                    item.extracts = nil
                } else {
                    item.encodeExtracts(extracts)
                }

                item.processingStatus = ProcessingStatus.completed.rawValue
                item.processingDetail = nil
                item.failureReason = nil
                try? ctx.save()
            }

            let verifyDesc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == itemID }
            )
            if let fresh = try? ctx.fetch(verifyDesc).first,
               !fresh.isArchived,
               fresh.status == .completed {
                fresh.indexInSpotlight()
            }

            return .finished(taskSuccess: true)
        } catch is PipelineLlmCancelled {
            return .cancelled
        } catch {
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

    nonisolated private static func upsertTagsOnItem(
        tagNames: [String],
        item: ContentItem,
        context: ModelContext
    ) {
        let unique = TagNameNormalizer.normalize(many: tagNames)
        if unique.isEmpty { return }
        let fetch = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { unique.contains($0.name) }
        )
        let existingTags = (try? context.fetch(fetch)) ?? []
        var existingByName: [String: Tag] = [:]
        for t in existingTags {
            existingByName[t.name] = t
        }
        for name in unique {
            let tag: Tag
            if let existing = existingByName[name] {
                tag = existing
            } else {
                let created = Tag(name: name)
                context.insert(created)
                existingByName[name] = created
                tag = created
            }
            if !item.tags.contains(where: { $0.name == tag.name }) {
                item.tags.append(tag)
            }
        }
    }

    /// Adds `#hashtag` tokens from captions for Instagram / TikTok web items after Llama tagging.
    nonisolated private static func mergePlatformHashtagTags(item: ContentItem, context: ModelContext) {
        guard item.kind == .web else { return }
        guard let host = item.displayHost?.lowercased() else { return }
        guard host.contains("instagram") || host.contains("tiktok") else { return }
        guard let raw = item.rawText else { return }
        let names = TagNameNormalizer.normalize(many: HashtagParser.tagNames(in: raw))
        upsertTagsOnItem(tagNames: names, item: item, context: context)
    }
}
