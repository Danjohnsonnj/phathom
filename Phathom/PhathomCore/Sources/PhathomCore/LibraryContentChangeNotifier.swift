import Foundation

public extension Notification.Name {
    /// Posted when library-visible `ContentItem` data may have changed (titles, tags, body text, pipeline state, etc.).
    /// Library search bucketing listens and bumps a lightweight revision instead of hashing the whole library on every view update.
    static let phathomLibraryContentDidChange = Notification.Name("phathom.libraryContentDidChange")
}

public enum LibraryContentChangeNotifier {
    public static func postLibraryContentDidChange() {
        NotificationCenter.default.post(name: .phathomLibraryContentDidChange, object: nil)
    }
}
