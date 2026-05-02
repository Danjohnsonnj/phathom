import Foundation

public enum PhathomAppGroup {
    /// Must match entitlements on the app and Share Extension.
    public static let identifier = "group.com.phathom.Phathom"

    public static let storeChangedDarwinNotificationName = "com.phathom.storeChanged"

    public static func sharedStoreURL() -> URL {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group container unavailable. Add the App Group capability and matching identifier.")
        }
        let library = root.appendingPathComponent("Library/Application Support", isDirectory: true)
        if !FileManager.default.fileExists(atPath: library.path) {
            try? FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        }
        return library.appendingPathComponent("Phathom.store", isDirectory: false)
    }
}
