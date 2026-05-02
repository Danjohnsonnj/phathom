import Foundation

/// Copies a legacy default SwiftData package from the app sandbox into the App Group store URL once.
public enum SwiftDataStoreMigration {
    private static let completedKey = "phathom.migratedStoreToAppGroup.v1"

    /// Call before creating `ModelContainer` at the shared URL. Safe to call repeatedly.
    public static func migrateLegacyStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        guard let defaults = UserDefaults(suiteName: PhathomAppGroup.identifier) else { return }

        if defaults.bool(forKey: completedKey) { return }

        let dest = PhathomAppGroup.sharedStoreURL()
        let destParent = dest.deletingLastPathComponent()
        try? fm.createDirectory(at: destParent, withIntermediateDirectories: true)

        if fm.fileExists(atPath: dest.path) {
            defaults.set(true, forKey: completedKey)
            return
        }

        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        guard let items = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) else {
            return
        }

        for src in items where src.lastPathComponent.hasSuffix(".store") {
            do {
                try fm.copyItem(at: src, to: dest)
            } catch {
                continue
            }
            break
        }

        defaults.set(true, forKey: completedKey)
    }
}
