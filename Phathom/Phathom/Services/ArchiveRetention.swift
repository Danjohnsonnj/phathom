import PhathomCore
import Foundation
import SwiftData

enum ArchiveRetention {
    private static let retentionSeconds: TimeInterval = 48 * 60 * 60

    /// When archive is triggered, stop treating the item as pipeline-work: clear partial AI (non-terminal rows),
    /// set idle `.failed`, or only clear **Regenerating tags…** noise on `.completed`/`.failed`.
    @MainActor
    static func pauseProcessingForArchive(_ item: ContentItem) {
        switch item.status {
        case .completed, .failed:
            item.processingDetail = nil
        default:
            ProcessingRecovery.clearAIDerivedFields(item)
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = nil
            item.processingDetail = nil
        }
    }

    /// Invoke after `save()` for the archiving transaction so the pipeline reads `isArchived` before cooperative cancel.
    nonisolated static func notifyProcessingCancelAfterArchiveCommitted(itemIDs: [UUID]) {
        guard !itemIDs.isEmpty else { return }
        BackgroundPipeline.cancelProcessing(for: itemIDs)
    }

    /// Permanently removes archived items past the retention window (48h after `archivedAt`).
    @MainActor
    static func purgeExpired(in context: ModelContext) {
        let cutoff = Date().addingTimeInterval(-retentionSeconds)
        let predicate = #Predicate<ContentItem> { item in
            item.isArchived == true
        }
        let descriptor = FetchDescriptor<ContentItem>(predicate: predicate)
        guard let archived = try? context.fetch(descriptor) else { return }
        let expired = archived.filter { item in
            guard let d = item.archivedAt else { return false }
            return d < cutoff
        }
        guard !expired.isEmpty else { return }
        for item in expired {
            context.delete(item)
        }
        try? context.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
    }

    @MainActor
    static func archive(_ item: ContentItem, in context: ModelContext) {
        pauseProcessingForArchive(item)
        FocusStackService.dropFocusEntryOnArchive(item: item, in: context)
        item.isArchived = true
        item.archivedAt = Date()
        item.removeFromSpotlight()
    }

    static func restore(_ item: ContentItem) {
        item.isArchived = false
        item.archivedAt = nil
        if item.status == .completed {
            item.indexInSpotlight()
        }
    }

    /// Human-readable time until hard delete (for Recently Deleted rows).
    static func timeUntilPermanentDeletion(from archivedAt: Date, now: Date = Date()) -> String {
        let deadline = archivedAt.addingTimeInterval(retentionSeconds)
        if deadline <= now {
            return "Deleting soon"
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(deadline) {
            return "Deletes today"
        }
        let startNow = calendar.startOfDay(for: now)
        let startDeadline = calendar.startOfDay(for: deadline)
        let days = calendar.dateComponents([.day], from: startNow, to: startDeadline).day ?? 0
        if days <= 1 {
            return "Permanently deletes in 1 day"
        }
        return "Permanently deletes in \(days) days"
    }
}
