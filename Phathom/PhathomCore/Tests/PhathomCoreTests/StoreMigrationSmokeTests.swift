import PhathomCore
import SwiftData
import XCTest

/// Scripted upgrade: V1 on-disk store → open with `PhathomSchemaV3` **without** migration plan, then persist `Highlight`.
/// App Group legacy copy (`SwiftDataStoreMigration`) depends on real container paths; smoke that path manually on device if needed.
final class StoreMigrationSmokeTests: XCTestCase {
    func testV1StoreFileMigratesToV3AndAcceptsHighlights() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("phathom-migration-smoke-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        try autoreleasepool {
            let v1Schema = Schema(versionedSchema: PhathomSchemaV1.self)
            let v1Config = ModelConfiguration(schema: v1Schema, url: url)
            let v1Container = try ModelContainer(for: v1Schema, configurations: [v1Config])
            let ctx1 = ModelContext(v1Container)
            let item = ContentItem()
            ctx1.insert(item)
            try ctx1.save()
        }

        let schema = PhathomModelContainer.currentSchema
        let v3Config = ModelConfiguration(schema: schema, url: url)
        let v3Container = try ModelContainer(for: schema, configurations: [v3Config])
        let ctx3 = ModelContext(v3Container)
        let items = try ctx3.fetch(FetchDescriptor<ContentItem>())
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)

        let h = Highlight(plainTextOffset: 0, plainTextLength: 1, quotedText: "x")
        ctx3.insert(h)
        item.highlights.append(h)
        try ctx3.save()

        XCTAssertEqual(item.highlights.count, 1)
        XCTAssertEqual(item.highlights.first?.quotedText, "x")
    }
}
