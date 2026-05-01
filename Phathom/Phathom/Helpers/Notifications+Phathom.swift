import Foundation

extension Notification.Name {
    static let openPhathomItem = Notification.Name("openPhathomItem")
    /// userInfo: itemID (UUID) — show archive undo toast in Library.
    static let phathomDidArchiveItem = Notification.Name("phathom.didArchiveItem")
}
