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

        let h = Highlight(sourceMarkdownOffset: 0, sourceMarkdownLength: 1, quotedText: "x")
        ctx3.insert(h)
        item.highlights.append(h)
        try ctx3.save()

        XCTAssertEqual(item.highlights.count, 1)
        XCTAssertEqual(item.highlights.first?.quotedText, "x")
    }

    func testV4StoreMigratesToV5AndAcceptsFocusEntry() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("phathom-migration-v4-v5-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        try autoreleasepool {
            let v4Schema = Schema(versionedSchema: PhathomSchemaV4.self)
            let v4Config = ModelConfiguration(schema: v4Schema, url: url)
            let v4Container = try ModelContainer(for: v4Schema, configurations: [v4Config])
            let ctx4 = ModelContext(v4Container)
            let item = ContentItem()
            ctx4.insert(item)
            try ctx4.save()
        }

        let schema = PhathomModelContainer.currentSchema
        let v5Config = ModelConfiguration(schema: schema, url: url)
        let v5Container = try ModelContainer(for: schema, configurations: [v5Config])
        let ctx5 = ModelContext(v5Container)
        let items = try ctx5.fetch(FetchDescriptor<ContentItem>())
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertNil(item.focusEntry)
        XCTAssertTrue(item.focusOutcomes.isEmpty)

        let entry = FocusEntry(contentItem: item, sortOrder: 0)
        ctx5.insert(entry)
        item.focusEntry = entry
        try ctx5.save()

        XCTAssertNotNil(item.focusEntry)
        XCTAssertEqual(item.focusEntry?.sortOrder, 0)
        XCTAssertEqual(item.focusEntry?.lastTouchedAt, item.focusEntry?.addedAt)
    }
}
