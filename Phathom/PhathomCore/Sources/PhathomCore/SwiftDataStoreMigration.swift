import Foundation
import SwiftData

/// Copies a legacy default SwiftData package from the main app sandbox into the shared store URL once.
public enum SwiftDataStoreMigration {
    /// When set (unit tests only), drives migration paths instead of live App Group / bundle locations.
    internal struct TestOverrides {
        var isAppExtension: Bool
        var usesMacSharedFallback: Bool
        var sharedStoreRoot: URL
        var legacyApplicationSupport: URL
        var sharedStoreURL: URL
        var migrationMarkerURL: URL
    }

    nonisolated(unsafe) internal static var testOverrides: TestOverrides?

    /// Call before creating `ModelContainer` at the shared URL. Safe to call repeatedly.
    /// Share extensions skip migration; only the main app copies legacy sandbox data.
    public static func migrateLegacyStoreToAppGroupIfNeeded() {
        if isRunningInAppExtension { return }
        if isStoreMigrationComplete() { return }

        let fm = FileManager.default
        let dest = resolvedSharedStoreURL()
        let destParent = dest.deletingLastPathComponent()
        try? fm.createDirectory(at: destParent, withIntermediateDirectories: true)

        guard let legacy = findLegacyStore(in: resolvedLegacyApplicationSupport()) else {
            setStoreMigrationComplete()
            return
        }

        if fm.fileExists(atPath: dest.path) {
            if storeHasLibraryContent(at: dest) {
                setStoreMigrationComplete()
                return
            }
            try? fm.removeItem(at: dest)
        }

        do {
            try fm.copyItem(at: legacy, to: dest)
        } catch {
            return
        }

        setStoreMigrationComplete()
    }

    private static var isRunningInAppExtension: Bool {
        if let testOverrides { return testOverrides.isAppExtension }
        return Bundle.main.bundleURL.pathExtension == "appex"
    }

    private static func isStoreMigrationComplete() -> Bool {
        if let testOverrides {
            if testOverrides.usesMacSharedFallback {
                return FileManager.default.fileExists(atPath: testOverrides.migrationMarkerURL.path)
            }
            return UserDefaults.standard.bool(forKey: "phathom.test.migrationComplete")
        }
        return PhathomAppGroup.isStoreMigrationComplete()
    }

    private static func setStoreMigrationComplete() {
        if let testOverrides {
            if testOverrides.usesMacSharedFallback {
                let marker = testOverrides.migrationMarkerURL
                try? FileManager.default.createDirectory(
                    at: marker.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                FileManager.default.createFile(atPath: marker.path, contents: Data(), attributes: nil)
            } else {
                UserDefaults.standard.set(true, forKey: "phathom.test.migrationComplete")
            }
            return
        }
        PhathomAppGroup.setStoreMigrationComplete()
    }

    private static func resolvedSharedStoreURL() -> URL {
        testOverrides?.sharedStoreURL ?? PhathomAppGroup.sharedStoreURL()
    }

    private static func resolvedLegacyApplicationSupport() -> URL {
        testOverrides?.legacyApplicationSupport
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private static func findLegacyStore(in applicationSupport: URL) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: applicationSupport,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        return items.first { $0.lastPathComponent.hasSuffix(".store") }
    }

    private static func storeHasLibraryContent(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let schema = PhathomModelContainer.currentSchema
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let count = try context.fetchCount(FetchDescriptor<ContentItem>())
            return count > 0
        } catch {
            return true
        }
    }
}
