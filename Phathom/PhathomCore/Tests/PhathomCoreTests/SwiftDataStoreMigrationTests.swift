@testable import PhathomCore
import SwiftData
import XCTest

final class SwiftDataStoreMigrationTests: XCTestCase {
    private var tempRoot: URL!
    private var legacySupport: URL!
    private var sharedRoot: URL!
    private var destStore: URL!
    private var marker: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("phathom-migration-\(UUID().uuidString)", isDirectory: true)
        legacySupport = tempRoot.appendingPathComponent("legacy-support", isDirectory: true)
        sharedRoot = tempRoot.appendingPathComponent("PhathomShared", isDirectory: true)
        destStore = sharedRoot
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("Phathom.store", isDirectory: false)
        marker = sharedRoot.appendingPathComponent(".phathom-store-migration-v1", isDirectory: false)
        try? FileManager.default.createDirectory(at: legacySupport, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "phathom.test.migrationComplete")
        SwiftDataStoreMigration.testOverrides = nil
    }

    override func tearDown() {
        SwiftDataStoreMigration.testOverrides = nil
        UserDefaults.standard.removeObject(forKey: "phathom.test.migrationComplete")
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    func testShareExtensionSkipsMigrationEvenWhenLegacyExists() throws {
        let legacyStore = legacySupport.appendingPathComponent("Phathom.store", isDirectory: false)
        try Data("legacy".utf8).write(to: legacyStore)

        SwiftDataStoreMigration.testOverrides = .init(
            isAppExtension: true,
            usesMacSharedFallback: true,
            sharedStoreRoot: sharedRoot,
            legacyApplicationSupport: legacySupport,
            sharedStoreURL: destStore,
            migrationMarkerURL: marker
        )

        SwiftDataStoreMigration.migrateLegacyStoreToAppGroupIfNeeded()

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destStore.path))
    }

    func testMainAppCopiesLegacyWhenShareExtensionCreatedEmptyDest() throws {
        let legacyStore = legacySupport.appendingPathComponent("Phathom.store", isDirectory: false)
        try writeEmptyStore(at: legacyStore, insertSampleItem: true)

        try FileManager.default.createDirectory(
            at: destStore.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeEmptyStore(at: destStore, insertSampleItem: false)

        SwiftDataStoreMigration.testOverrides = .init(
            isAppExtension: false,
            usesMacSharedFallback: true,
            sharedStoreRoot: sharedRoot,
            legacyApplicationSupport: legacySupport,
            sharedStoreURL: destStore,
            migrationMarkerURL: marker
        )

        SwiftDataStoreMigration.migrateLegacyStoreToAppGroupIfNeeded()

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        let count = try itemCount(at: destStore)
        XCTAssertEqual(count, 1)
    }

    func testMainAppDoesNotOverwriteSharedDestWithLibraryContent() throws {
        let legacyStore = legacySupport.appendingPathComponent("Legacy.store", isDirectory: false)
        try writeEmptyStore(at: legacyStore, insertSampleItem: true)

        try FileManager.default.createDirectory(
            at: destStore.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeEmptyStore(at: destStore, insertSampleItem: true)

        SwiftDataStoreMigration.testOverrides = .init(
            isAppExtension: false,
            usesMacSharedFallback: true,
            sharedStoreRoot: sharedRoot,
            legacyApplicationSupport: legacySupport,
            sharedStoreURL: destStore,
            migrationMarkerURL: marker
        )

        SwiftDataStoreMigration.migrateLegacyStoreToAppGroupIfNeeded()

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        let count = try itemCount(at: destStore)
        XCTAssertEqual(count, 1)
    }

    private func writeEmptyStore(at url: URL, insertSampleItem: Bool) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let schema = PhathomModelContainer.currentSchema
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        if insertSampleItem {
            let context = ModelContext(container)
            context.insert(ContentItem())
            try context.save()
        }
    }

    private func itemCount(at url: URL) throws -> Int {
        let schema = PhathomModelContainer.currentSchema
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return try context.fetchCount(FetchDescriptor<ContentItem>())
    }
}
