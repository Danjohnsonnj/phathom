import Foundation
import PhathomCore
import SwiftData
import XCTest

final class LibraryBackupServiceTests: XCTestCase {
    func testExportExcludesArchivedItems() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let active = makeItem(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 10),
            archived: false
        )
        active.tags = [Tag(name: "alpha")]
        let archived = makeItem(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 20),
            archived: true
        )
        archived.tags = [Tag(name: "beta")]

        context.insert(active)
        context.insert(archived)
        try context.save()

        let data = try LibraryBackupService.exportData(from: context, appBuild: "test-build")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(LibraryBackupService.ExportEnvelope.self, from: data)

        XCTAssertEqual(envelope.items.count, 1)
        XCTAssertEqual(envelope.items.first?.id, active.id)
    }

    func testImportMergeSkipsDuplicateIDs() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let existingID = UUID()
        let existing = makeItem(id: existingID, createdAt: Date(timeIntervalSince1970: 10), archived: false)
        context.insert(existing)
        try context.save()

        let duplicate = LibraryBackupService.ItemRecord(
            id: existingID,
            createdAt: Date(timeIntervalSince1970: 30),
            title: "dup",
            titleUserSet: false,
            originalURL: URL(string: "https://example.com/dup"),
            displayHost: "example.com",
            contentKind: ContentKind.web.rawValue,
            rawText: "dup",
            sourceMarkdown: nil,
            thumbnailData: nil,
            thumbnailColorHex: nil,
            mediaDescription: nil,
            summaryBullets: nil,
            extracts: nil,
            processingStatus: ProcessingStatus.pending.rawValue,
            processingDetail: nil,
            lastProcessedChunk: 0,
            failureReason: nil,
            isArchived: false,
            archivedAt: nil,
            tags: ["dup"]
        )
        let unique = LibraryBackupService.ItemRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 40),
            title: "unique",
            titleUserSet: true,
            originalURL: URL(string: "https://example.com/u"),
            displayHost: "example.com",
            contentKind: ContentKind.note.rawValue,
            rawText: "hello",
            sourceMarkdown: "# hi",
            thumbnailData: nil,
            thumbnailColorHex: "#ffffff",
            mediaDescription: nil,
            summaryBullets: "[\"x\"]",
            extracts: "[{\"label\":\"a\",\"value\":\"b\"}]",
            processingStatus: ProcessingStatus.completed.rawValue,
            processingDetail: "ok",
            lastProcessedChunk: 3,
            failureReason: nil,
            isArchived: false,
            archivedAt: nil,
            tags: ["ai", "news"]
        )
        let payload = LibraryBackupService.ExportEnvelope(appBuild: "test", items: [duplicate, unique])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let result = try LibraryBackupService.importData(data, policy: .merge, into: context)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedDuplicateCount, 1)

        let all = try context.fetch(FetchDescriptor<ContentItem>())
        XCTAssertEqual(all.count, 2)
    }

    func testImportReplaceDeletesExistingAndLoadsBackup() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let existing = makeItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 10), archived: true)
        context.insert(existing)
        try context.save()

        let incoming = LibraryBackupService.ItemRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 50),
            title: "restored",
            titleUserSet: true,
            originalURL: URL(string: "https://example.com/restored"),
            displayHost: "example.com",
            contentKind: ContentKind.web.rawValue,
            rawText: "body",
            sourceMarkdown: "md",
            thumbnailData: Data([1, 2, 3]),
            thumbnailColorHex: "#000000",
            mediaDescription: "desc",
            summaryBullets: "[\"a\"]",
            extracts: "[]",
            processingStatus: ProcessingStatus.completed.rawValue,
            processingDetail: "done",
            lastProcessedChunk: 9,
            failureReason: nil,
            isArchived: false,
            archivedAt: nil,
            tags: ["restore"]
        )

        let envelope = LibraryBackupService.ExportEnvelope(appBuild: "test", items: [incoming])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)

        let result = try LibraryBackupService.importData(data, policy: .replace, into: context)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedDuplicateCount, 0)
        XCTAssertEqual(result.existingCountBeforeImport, 1)

        let all = try context.fetch(FetchDescriptor<ContentItem>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "restored")
        XCTAssertEqual(all.first?.tagNames, ["restore"])
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeItem(id: UUID, createdAt: Date, archived: Bool) -> ContentItem {
        let item = ContentItem(
            id: id,
            createdAt: createdAt,
            contentKind: .web,
            originalURL: URL(string: "https://example.com/\(id.uuidString)")!
        )
        item.title = "title-\(id.uuidString)"
        item.titleUserSet = true
        item.displayHost = "example.com"
        item.rawText = "raw"
        item.sourceMarkdown = "md"
        item.thumbnailData = Data([9, 9, 9])
        item.thumbnailColorHex = "#123456"
        item.mediaDescription = "desc"
        item.summaryBullets = "[\"one\"]"
        item.extracts = "[{\"label\":\"a\",\"value\":\"b\"}]"
        item.processingStatus = ProcessingStatus.completed.rawValue
        item.processingDetail = "detail"
        item.lastProcessedChunk = 2
        item.failureReason = nil
        item.isArchived = archived
        item.archivedAt = archived ? Date(timeIntervalSince1970: 500) : nil
        return item
    }
}
