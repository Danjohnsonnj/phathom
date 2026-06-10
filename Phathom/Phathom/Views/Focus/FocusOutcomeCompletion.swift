import Foundation
import PhathomCore
import SwiftData

enum FocusOutcomeCompletion {
    @MainActor
    @discardableResult
    static func complete(
        item: ContentItem,
        kind: FocusOutcomeKind,
        modelContext: ModelContext,
        takeawayText: String? = nil,
        linkedHighlightID: UUID? = nil,
        scheduledResurfaceAt: Date? = nil
    ) -> Bool {
        guard FocusStackService.isInFocus(item) else { return false }
        do {
            try FocusStackService.completeOutcome(
                item: item,
                kind: kind,
                in: modelContext,
                takeawayText: takeawayText,
                linkedHighlightID: linkedHighlightID,
                scheduledResurfaceAt: scheduledResurfaceAt
            )
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            return true
        } catch {
            return false
        }
    }

    @MainActor
    @discardableResult
    static func completeReference(
        item: ContentItem,
        category: PhathomCore.Category?,
        modelContext: ModelContext
    ) -> Bool {
        item.applyFiled(category: category, modelContext: modelContext)
        return complete(item: item, kind: .reference, modelContext: modelContext)
    }
}
