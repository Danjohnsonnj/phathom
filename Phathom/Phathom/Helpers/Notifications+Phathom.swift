import PhathomCore
import Foundation

extension Notification.Name {
    static let openPhathomItem = Notification.Name("openPhathomItem")
    /// userInfo: `itemID` (UUID). Optional `switchToLibrary` (Bool, default `true`): when `true`, `MainTabView` selects the Library tab so the bottom undo snackbar is visible; set `false` only for future call sites that archive outside Library and handle their own UX.
    static let phathomDidArchiveItem = Notification.Name("phathom.didArchiveItem")
    /// Posted after Recently Deleted (or similar) changes archived-item count so Settings can refresh its badge without relying on scene phase.
    static let phathomArchivedItemsDidChange = Notification.Name("phathom.archivedItemsDidChange")
    /// Model file selection or load outcome changed; Library (and similar) should refresh lightweight indicators.
    static let phathomModelAvailabilityDidChange = Notification.Name("phathom.modelAvailabilityDidChange")
}
