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
