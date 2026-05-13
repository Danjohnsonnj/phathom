import PhathomCore
import Foundation

extension Notification.Name {
    static let openPhathomItem = Notification.Name("openPhathomItem")
    /// userInfo: primary `itemIDs` (`[String]` UUID strings); legacy `itemID` (`UUID`) when absent. Optional `switchToLibrary` (Bool, default `true`): when `true`, `MainTabView` selects the Library tab so the bottom undo snackbar is visible; set `false` only for future call sites that archive outside Library and handle their own UX.
    static let phathomDidArchiveItem = Notification.Name("phathom.didArchiveItem")
    /// Posted after Recently Deleted (or similar) changes archived-item count so Settings can refresh its badge without relying on scene phase.
    static let phathomArchivedItemsDidChange = Notification.Name("phathom.archivedItemsDidChange")
    /// Model file selection or load outcome changed; Library (and similar) should refresh lightweight indicators.
    static let phathomModelAvailabilityDidChange = Notification.Name("phathom.modelAvailabilityDidChange")
}

/// Canonical `userInfo` keys + parsing for `phathomDidArchiveItem` (bulk + single archive).
enum PhathomArchiveNotification {
    static let itemIDsKey = "itemIDs"
    static let itemIDKey = "itemID"
    static let switchToLibraryKey = "switchToLibrary"

    /// Plist-safe `itemIDs` as UUID strings; mirrors `itemID` when exactly one id for legacy readers.
    static func userInfo(itemIDs: [UUID], switchToLibrary: Bool = true) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            itemIDsKey: itemIDs.map(\.uuidString),
            switchToLibraryKey: switchToLibrary,
        ]
        if itemIDs.count == 1, let only = itemIDs.first {
            info[itemIDKey] = only
        }
        return info
    }

    /// Returns archived ids in order, or `nil` if nothing recognized.
    static func itemIDs(from userInfo: [AnyHashable: Any]?) -> [UUID]? {
        guard let userInfo else { return nil }
        if let strings = userInfo[itemIDsKey] as? [String] {
            let uuids = strings.compactMap(UUID.init(uuidString:))
            if !uuids.isEmpty { return uuids }
        }
        if let id = userInfo[itemIDKey] as? UUID {
            return [id]
        }
        if let s = userInfo[itemIDKey] as? String, let u = UUID(uuidString: s) {
            return [u]
        }
        return nil
    }
}
