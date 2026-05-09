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
}
