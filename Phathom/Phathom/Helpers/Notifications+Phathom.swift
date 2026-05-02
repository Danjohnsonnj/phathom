import PhathomCore
import Foundation

extension Notification.Name {
    static let openPhathomItem = Notification.Name("openPhathomItem")
    /// userInfo: `itemID` (UUID). Optional `switchToLibrary` (Bool, default `true`): when `true`, `MainTabView` selects the Library tab so the bottom undo snackbar is visible; set `false` only for future call sites that archive outside Library and handle their own UX.
    static let phathomDidArchiveItem = Notification.Name("phathom.didArchiveItem")
}
