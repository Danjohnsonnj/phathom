import Foundation

public enum PhathomAppGroup {
    /// Must match entitlements on the app and Share Extension (iOS).
    public static let identifier = "group.com.phathom.Phathom"

    public static let storeChangedDarwinNotificationName = "com.phathom.storeChanged"

    /// Non–App Group store root on macOS when ad-hoc signing omits application-groups (Phase 5).
    private static let macFallbackSupportFolderName = "PhathomShared"

    private static let migrationCompletedDefaultsKey = "phathom.migratedStoreToAppGroup.v1"
    private static let migrationMarkerFileName = ".phathom-store-migration-v1"

    /// `true` when the shared store uses the macOS Application Support fallback (no App Group container).
    public static var usesMacSharedFallback: Bool {
        #if os(macOS)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) == nil
        #else
        false
        #endif
    }

    /// App Group container when entitled; on macOS falls back to a shared Application Support folder.
    public static func sharedStoreRootURL() -> URL {
        if let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return root
        }
        #if os(macOS)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent(macFallbackSupportFolderName, isDirectory: true)
        #else
        fatalError("App Group container unavailable. Add the App Group capability and matching identifier.")
        #endif
    }

    public static func sharedStoreURL() -> URL {
        let root = sharedStoreRootURL()
        let library = root.appendingPathComponent("Library/Application Support", isDirectory: true)
        if !FileManager.default.fileExists(atPath: library.path) {
            try? FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        }
        return library.appendingPathComponent("Phathom.store", isDirectory: false)
    }

    /// Shared suite when App Group is entitled; used for migration flags on iOS only.
    public static func migrationDefaults() -> UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static func isStoreMigrationComplete() -> Bool {
        if usesMacSharedFallback {
            return FileManager.default.fileExists(atPath: storeMigrationMarkerURL().path)
        }
        return migrationDefaults()?.bool(forKey: migrationCompletedDefaultsKey) ?? false
    }

    public static func setStoreMigrationComplete() {
        if usesMacSharedFallback {
            let marker = storeMigrationMarkerURL()
            try? FileManager.default.createDirectory(
                at: marker.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: marker.path, contents: Data(), attributes: nil)
            return
        }
        migrationDefaults()?.set(true, forKey: migrationCompletedDefaultsKey)
    }

    static func storeMigrationMarkerURL() -> URL {
        sharedStoreRootURL().appendingPathComponent(migrationMarkerFileName, isDirectory: false)
    }
}
