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

    /// Bulk move to `.filed` with optional structural category — one save + notifier.
    static func applyFiled(
        category: Category?,
        to items: [ContentItem],
        modelContext: ModelContext
    ) {
        guard !items.isEmpty else { return }
        for item in items {
            item.readStatus = ReadStatus.filed.rawValue
            item.category = category
        }
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
    }

    func applyFiled(category: Category?, modelContext: ModelContext) {
        Self.applyFiled(category: category, to: [self], modelContext: modelContext)
    }

    /// Sets structural category only (does not change read status). No-op if assignment unchanged.
    func applyCategory(_ category: Category?, modelContext: ModelContext) {
        let unchanged: Bool
        switch (self.category, category) {
        case (nil, nil):
            unchanged = true
        case (nil, .some), (.some, nil):
            unchanged = false
        case let (existing?, picked?):
            unchanged = existing.persistentModelID == picked.persistentModelID
        }
        guard !unchanged else { return }
        self.category = category
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        indexInSpotlight()
    }
}
