import Foundation
import PhathomCore
import SwiftData

enum ProcessingRecovery {
    /// Re-queues a failed item for ingest or LLM. Returns false if retry is not applicable (e.g. empty note).
    @MainActor
    @discardableResult
    static func retryFailedItemIfNeeded(_ item: ContentItem, modelContext: ModelContext) -> Bool {
        guard item.status == .failed, !item.isArchived else { return false }

        switch item.kind {
        case .media:
            normalizeFailedMedia(item)
            clearAIDerivedFields(item)
            item.failureReason = nil
            item.processingDetail = nil
            try? modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            item.indexInSpotlight()
            BackgroundPipeline.scheduleAll()
            BackgroundPipeline.scheduleForegroundDrain()
            return true

        case .note:
            guard rawTextNonEmpty(item) else { return false }
            clearAIDerivedFields(item)
            item.processingStatus = ProcessingStatus.embedding.rawValue
            item.processingDetail = "Preparing analysis…"
            item.failureReason = nil
            try? modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            BackgroundPipeline.scheduleAll()
            BackgroundPipeline.scheduleForegroundDrain()
            return true

        case .web:
            clearAIDerivedFields(item)
            item.failureReason = nil
            if rawTextNonEmpty(item) {
                item.processingStatus = ProcessingStatus.embedding.rawValue
                item.processingDetail = "Preparing analysis…"
            } else {
                item.processingStatus = ProcessingStatus.pending.rawValue
                item.processingDetail = "Queued for capture"
            }
            try? modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            BackgroundPipeline.scheduleAll()
            BackgroundPipeline.scheduleForegroundDrain()
            return true
        }
    }

    @MainActor
    static func canRetryFailed(_ item: ContentItem) -> Bool {
        guard item.status == .failed, !item.isArchived else { return false }
        switch item.kind {
        case .note:
            return rawTextNonEmpty(item)
        case .web, .media:
            return true
        }
    }

    /// Whether the user can re-run LLM analysis from the detail screen (completed web/note with body text).
    @MainActor
    static func canSummarizeAgain(_ item: ContentItem) -> Bool {
        guard !item.isArchived, item.status == .completed else { return false }
        switch item.kind {
        case .media:
            return false
        case .web, .note:
            return rawTextNonEmpty(item)
        }
    }

    /// Clears AI-derived fields and re-queues the item for the full analyze pass: new summary bullets, new tags
    /// (LLM plus platform hashtag merge), and new extracts — same `processNextEmbeddingItem` path as after scrape.
    @MainActor
    @discardableResult
    static func summarizeAgain(_ item: ContentItem, modelContext: ModelContext) -> Bool {
        guard canSummarizeAgain(item) else { return false }
        clearAIDerivedFields(item)
        item.failureReason = nil
        item.processingDetail = "Preparing analysis…"
        item.processingStatus = ProcessingStatus.embedding.rawValue
        item.lastProcessedChunk = 0
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        item.indexInSpotlight()
        BackgroundPipeline.scheduleAll()
        BackgroundPipeline.scheduleForegroundDrain()
        return true
    }

    private static func rawTextNonEmpty(_ item: ContentItem) -> Bool {
        guard let raw = item.rawText else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func clearAIDerivedFields(_ item: ContentItem) {
        item.summaryBullets = nil
        item.extracts = nil
        item.tags.removeAll()
    }

    private static func normalizeFailedMedia(_ item: ContentItem) {
        item.processingStatus = ProcessingStatus.completed.rawValue
        if (item.mediaDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            item.mediaDescription = ShareCapture.mediaPlaceholderDescription
        }
    }
}
