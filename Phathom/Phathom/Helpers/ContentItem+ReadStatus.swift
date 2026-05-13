import PhathomCore
import SwiftData

extension ContentItem {
    /// Persists user triage status and notifies library observers (same contract as Library swipe).
    func applyReadStatus(_ status: ReadStatus, modelContext: ModelContext) {
        guard readState != status else { return }
        readStatus = status.rawValue
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
    }

    /// Bulk triage: at most one save + one library notifier for the whole set.
    static func applyReadStatus(_ status: ReadStatus, to items: [ContentItem], modelContext: ModelContext) {
        var changed = false
        for item in items {
            guard item.readState != status else { continue }
            item.readStatus = status.rawValue
            changed = true
        }
        guard changed else { return }
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
    }
}
