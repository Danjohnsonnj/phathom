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

// LLM load/generate/unload is serialized by `SharedLlamaInference`'s `AsyncLock` (`withSession`).
// `PipelineWorkGate` additionally serializes `reviveAbortedPipelineItems` plus ingest/analyze passes so a second
// foreground drain or BG task cannot rewind `summarizing`/`tagging` rows while another pass is still running
// (e.g. Safari share sheet + Darwin notify + scene-active all scheduling drains).

enum BackgroundPipeline: Sendable {
    nonisolated(unsafe) private static var containerRef: ModelContainer?

    private nonisolated static func saveAndNotify(_ ctx: ModelContext) {
        try? ctx.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
    }

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
            guard let container = containerRef else { return }
            await PipelineWorkGate.shared.performForegroundDrain(modelContainer: container)
        }
    }

    nonisolated static func scheduleRetag(itemID: UUID) {
        Task(priority: .utility) {
            guard let container = containerRef else { return }
            await PipelineWorkGate.shared.performRetag(modelContainer: container, itemID: itemID)
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
    fileprivate nonisolated static func reviveAbortedPipelineItems(modelContainer: ModelContainer) {
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
        saveAndNotify(ctx)
    }

    /// Awaits the same serialized queue as `scheduleForegroundDrain` (tests or tooling may call this directly).
    nonisolated static func runForegroundDrain() async {
        guard let container = containerRef else { return }
        await PipelineWorkGate.shared.performForegroundDrain(modelContainer: container)
    }

    #if DEBUG
    /// Test-only seam: runs one pending-web ingest step (including malformed-row skip behavior).
    nonisolated static func _test_processNextPendingWebItem(modelContainer: ModelContainer) async -> Bool {
        await processNextPendingWebItem(modelContainer: modelContainer) { false }
    }
    #endif

    fileprivate nonisolated static func runForegroundDrainBody(modelContainer container: ModelContainer) async {
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
            await PipelineWorkGate.shared.performBackgroundIngest(
                modelContainer: container,
                cancel: { cancelFlag.value }
            )

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
            let outcome = await PipelineWorkGate.shared.performBackgroundAnalyze(
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

    fileprivate nonisolated static func processNextPendingWebItem(
        modelContainer: ModelContainer,
        cancel: @Sendable @escaping () -> Bool
    ) async -> Bool {
        let ctx = ModelContext(modelContainer)
        while true {
            var desc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { item in
                    !item.isArchived && item.processingStatus == "pending" && item.contentKind == "web"
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            desc.fetchLimit = 1

            guard let item = try? ctx.fetch(desc).first else {
                return false
            }

            guard item.originalURL != nil else {
                // A malformed queue head (pending web with nil URL) must not block later queued rows.
                item.processingStatus = ProcessingStatus.failed.rawValue
                item.processingDetail = nil
                item.failureReason = "Capture payload missing URL."
                saveAndNotify(ctx)
                print("[PhathomPipeline] pending_skip item=\(item.id.uuidString) reason=missing_url")
                continue
            }

            if cancel() { return false }

            print("[PhathomPipeline] pending_pick item=\(item.id.uuidString)")

            if !NetworkReachability.hasUsableConnection {
                item.processingStatus = ProcessingStatus.pending.rawValue
                item.processingDetail = "Waiting for network…"
                item.failureReason = nil
                saveAndNotify(ctx)
                print("[PhathomPipeline] pending_stop item=\(item.id.uuidString) reason=offline")
                return false
            }

            item.processingStatus = ProcessingStatus.scraping.rawValue
            item.processingDetail = "Fetching article…"
            saveAndNotify(ctx)

            do {
                guard let url = item.originalURL else { return false }
                let scrapeItemID = item.id
                let result = try await PipelineMetrics.time("scrape", itemID: scrapeItemID) {
                    try await WebIngestService.scrape(url: url)
                }
                item.rawText = result.text
                item.sourceMarkdown = result.sourceMarkdown
                if let t = result.thumbnailData { item.thumbnailData = t }
                item.displayHost = result.displayHost
                if !item.titleUserSet {
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
                saveAndNotify(ctx)
                print("[PhathomPipeline] pending_done item=\(item.id.uuidString) next=continue")
                return true
            } catch WebIngestError.offline {
                item.processingStatus = ProcessingStatus.pending.rawValue
                item.processingDetail = "Waiting for network…"
                item.failureReason = nil
                saveAndNotify(ctx)
                // Returning false stops `runForegroundDrain`'s ingest loop from immediately re-fetching the same
                // still-`pending` row (would thrash scraping ↔ pending). `NetworkReachability` + next drain retry.
                print("[PhathomPipeline] pending_stop item=\(item.id.uuidString) reason=scrape_offline")
                return false
            } catch {
                item.processingStatus = ProcessingStatus.failed.rawValue
                item.failureReason = error.localizedDescription
                item.processingDetail = nil
                saveAndNotify(ctx)
                print("[PhathomPipeline] pending_done item=\(item.id.uuidString) next=continue result=failed")
                return true
            }
        }
    }

    fileprivate nonisolated static func processNextEmbeddingItem(
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
            saveAndNotify(ctx)
            item.indexInSpotlight()
            return .finished(taskSuccess: true)
        }

        guard let raw = item.rawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = "No article text to analyze."
            saveAndNotify(ctx)
            return .finished(taskSuccess: false)
        }

        let article = String(raw.prefix(12_000))

        do {
            try await SharedLlamaInference.shared.withSession(unloadOnExit: true, pipelineItemID: itemID) { session in
                if cancel() {
                    await session.cancelInFlight()
                    checkpointAfterCancel(item: item)
                    saveAndNotify(ctx)
                    throw PipelineLlmCancelled()
                }

                item.processingStatus = ProcessingStatus.summarizing.rawValue
                item.processingDetail = "Generating summary…"
                saveAndNotify(ctx)

                // All three analysis tasks share a single prefill of the article body via KV cache
                // prefix reuse. The `onPartial` callback fires after each task's decode completes
                // — before the next task's suffix begins — preserving the original checkpointing
                // granularity (summary saved before tags decode, tags saved before extracts decode).
                var stageStart = Date()

                try await session.analyze(article) { partial in
                    switch partial {
                    case .summary(let bullets):
                        PipelineMetrics.logSyncElapsed("summarize", itemID: itemID, start: stageStart)
                        stageStart = Date()
                        if bullets.isEmpty { item.summaryBullets = nil } else { item.encodeSummaryBullets(bullets) }
                        saveAndNotify(ctx)

                        if cancel() { return }
                        item.processingStatus = ProcessingStatus.tagging.rawValue
                        item.processingDetail = "Auto-tagging…"
                        saveAndNotify(ctx)

                    case .tags(let tagNames):
                        PipelineMetrics.logSyncElapsed("tags_llm", itemID: itemID, start: stageStart)
                        stageStart = Date()
                        let tagDbStart = Date()
                        // Replace the item's tag set for this run (do not accumulate).
                        item.tags.removeAll()
                        upsertTagsOnItem(tagNames: tagNames, item: item, context: ctx)
                        mergePlatformHashtagTags(item: item, context: ctx)
                        PipelineMetrics.logSyncElapsed("tag_db", itemID: itemID, start: tagDbStart)
                        saveAndNotify(ctx)

                        if cancel() { return }
                        item.processingDetail = "Extracting key information…"
                        saveAndNotify(ctx)

                    case .extracts(let extracts):
                        PipelineMetrics.logSyncElapsed("extracts_llm", itemID: itemID, start: stageStart)
                        if extracts.isEmpty { item.extracts = nil } else { item.encodeExtracts(extracts) }
                    }
                }

                if cancel() {
                    await session.cancelInFlight()
                    checkpointAfterCancel(item: item)
                    saveAndNotify(ctx)
                    throw PipelineLlmCancelled()
                }

                item.processingStatus = ProcessingStatus.completed.rawValue
                item.processingDetail = nil
                item.failureReason = nil
                saveAndNotify(ctx)
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
            saveAndNotify(ctx)
            return .finished(taskSuccess: false)
        }
    }

    /// User-initiated tags-only refresh: `session.tags`, replace tags + platform hashtag merge; stays `completed`.
    fileprivate nonisolated static func performRetag(modelContainer: ModelContainer, itemID: UUID) async {
        reviveAbortedPipelineItems(modelContainer: modelContainer)

        if ThermalMonitor.shouldThrottle {
            let ctx = ModelContext(modelContainer)
            let throttleDesc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == itemID }
            )
            if let item = try? ctx.fetch(throttleDesc).first {
                item.processingDetail = nil
                saveAndNotify(ctx)
            }
            scheduleAll()
            return
        }

        if !ModelManager.hasReadableSelection {
            let ctx = ModelContext(modelContainer)
            let noModelDesc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == itemID }
            )
            if let item = try? ctx.fetch(noModelDesc).first {
                item.processingDetail = nil
                saveAndNotify(ctx)
            }
            return
        }

        let ctx = ModelContext(modelContainer)
        let desc = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { $0.id == itemID }
        )
        guard let item = try? ctx.fetch(desc).first else { return }

        guard !item.isArchived,
              item.status == .completed,
              item.kind == .web || item.kind == .note,
              let raw = item.rawText,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            item.processingDetail = nil
            saveAndNotify(ctx)
            return
        }

        let article = String(raw.prefix(12_000))

        do {
            try await SharedLlamaInference.shared.withSession(unloadOnExit: true, pipelineItemID: itemID) { session in
                let tagNames = try await session.tags(article)
                item.tags.removeAll()
                upsertTagsOnItem(tagNames: tagNames, item: item, context: ctx)
                mergePlatformHashtagTags(item: item, context: ctx)
                saveAndNotify(ctx)
            }

            let verifyDesc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == itemID }
            )
            if let fresh = try? ctx.fetch(verifyDesc).first,
               !fresh.isArchived,
               fresh.status == .completed {
                fresh.processingDetail = nil
                fresh.failureReason = nil
                saveAndNotify(ctx)
                fresh.indexInSpotlight()
            } else {
                item.processingDetail = nil
                saveAndNotify(ctx)
            }
        } catch {
            let errDesc = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == itemID }
            )
            if let fresh = try? ctx.fetch(errDesc).first {
                fresh.processingDetail = nil
                saveAndNotify(ctx)
            }
            print("[PhathomPipeline] retag_failed item=\(itemID.uuidString) error=\(error.localizedDescription)")
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

// MARK: - Serialize revive + ingest/analyze (foreground + BG)

/// FIFO async lock around all pipeline entry points so `reviveAbortedPipelineItems` never runs while another
/// pass holds rows in `summarizing` or `tagging`. Uses `AsyncLock` (non-reentrant FIFO) rather than a Swift
/// actor, which would be reentrant at every `await` suspension point.
private final class PipelineWorkGate: @unchecked Sendable {
    static let shared = PipelineWorkGate()
    private let lock = AsyncLock()

    func performForegroundDrain(modelContainer: ModelContainer) async {
        await lock.withLock { @Sendable [modelContainer] in
            await BackgroundPipeline.runForegroundDrainBody(modelContainer: modelContainer)
        }
    }

    func performBackgroundIngest(
        modelContainer: ModelContainer,
        cancel: @Sendable @escaping () -> Bool
    ) async {
        await lock.withLock { @Sendable [modelContainer] in
            await MainActor.run {
                let purgeCtx = ModelContext(modelContainer)
                ArchiveRetention.purgeExpired(in: purgeCtx)
            }
            BackgroundPipeline.reviveAbortedPipelineItems(modelContainer: modelContainer)
            var processed = 0
            while !cancel() && processed < 3 {
                let did = await BackgroundPipeline.processNextPendingWebItem(
                    modelContainer: modelContainer,
                    cancel: cancel
                )
                if !did { break }
                processed += 1
            }
        }
    }

    func performBackgroundAnalyze(
        modelContainer: ModelContainer,
        cancel: @Sendable @escaping () -> Bool
    ) async -> SingleAnalyzeOutcome {
        await lock.withLock { @Sendable [modelContainer] in
            BackgroundPipeline.reviveAbortedPipelineItems(modelContainer: modelContainer)
            return await BackgroundPipeline.processNextEmbeddingItem(
                modelContainer: modelContainer,
                cancel: cancel
            )
        }
    }

    func performRetag(modelContainer: ModelContainer, itemID: UUID) async {
        await lock.withLock { @Sendable [modelContainer] in
            await BackgroundPipeline.performRetag(modelContainer: modelContainer, itemID: itemID)
        }
    }
}
