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

    func testHighlightExportImportRoundTrip() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let item = makeItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 100), archived: false)
        let mdBody = String(repeating: "x", count: 60)
        item.sourceMarkdown = mdBody
        context.insert(item)

        let highlight = Highlight(
            sourceMarkdownOffset: 10,
            sourceMarkdownLength: 25,
            quotedText: String(repeating: "x", count: 25),
            userNote: "my note"
        )
        highlight.item = item
        context.insert(highlight)
        try context.save()

        let data = try LibraryBackupService.exportData(from: context, appBuild: "test")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(LibraryBackupService.ExportEnvelope.self, from: data)
        XCTAssertEqual(envelope.formatVersion, 2)
        XCTAssertEqual(envelope.items.count, 1)
        XCTAssertEqual(envelope.items.first?.highlights.count, 1)

        let hr = try XCTUnwrap(envelope.items.first?.highlights.first)
        XCTAssertEqual(hr.sourceMarkdownOffset, 10)
        XCTAssertEqual(hr.sourceMarkdownLength, 25)
        XCTAssertEqual(hr.quotedText, String(repeating: "x", count: 25))
        XCTAssertEqual(hr.userNote, "my note")

        let importContainer = try makeInMemoryContainer()
        let importContext = ModelContext(importContainer)
        let result = try LibraryBackupService.importData(data, policy: .replace, into: importContext)
        XCTAssertEqual(result.importedCount, 1)

        let imported = try importContext.fetch(FetchDescriptor<ContentItem>())
        XCTAssertEqual(imported.count, 1)

        let importedHighlights = try importContext.fetch(FetchDescriptor<Highlight>())
        XCTAssertEqual(importedHighlights.count, 1)

        let ih = try XCTUnwrap(importedHighlights.first)
        XCTAssertEqual(ih.sourceMarkdownOffset, 10)
        XCTAssertEqual(ih.sourceMarkdownLength, 25)
        XCTAssertEqual(ih.quotedText, String(repeating: "x", count: 25))
        XCTAssertEqual(ih.userNote, "my note")
        XCTAssertEqual(ih.item?.id, item.id)
    }

    func testV1FormatImportsWithEmptyHighlights() throws {
        let v1Record = LibraryBackupService.ItemRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 10),
            title: "v1 item",
            titleUserSet: false,
            originalURL: URL(string: "https://example.com"),
            displayHost: "example.com",
            contentKind: ContentKind.web.rawValue,
            rawText: "text",
            sourceMarkdown: nil,
            thumbnailData: nil,
            thumbnailColorHex: nil,
            mediaDescription: nil,
            summaryBullets: nil,
            extracts: nil,
            processingStatus: ProcessingStatus.completed.rawValue,
            processingDetail: nil,
            lastProcessedChunk: 0,
            failureReason: nil,
            isArchived: false,
            archivedAt: nil,
            tags: []
        )
        let envelope = LibraryBackupService.ExportEnvelope(
            formatVersion: 1,
            appBuild: "test",
            items: [v1Record]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let result = try LibraryBackupService.importData(data, policy: .replace, into: context)
        XCTAssertEqual(result.importedCount, 1)

        let highlights = try context.fetch(FetchDescriptor<Highlight>())
        XCTAssertTrue(highlights.isEmpty)
    }

    func testV1JSONWithoutHighlightsKeyImports() throws {
        let itemID = "00000000-0000-4000-8000-000000000001"
        let json = """
        {
          "appBuild": "raw-v1",
          "exportedAt": "2020-05-15T12:00:00.000Z",
          "formatVersion": 1,
          "items": [
            {
              "id": "\(itemID)",
              "createdAt": "1970-01-01T00:00:10.000Z",
              "title": "v1 raw",
              "titleUserSet": false,
              "originalURL": "https://example.com/raw",
              "displayHost": "example.com",
              "contentKind": "web",
              "rawText": "body",
              "sourceMarkdown": null,
              "thumbnailData": null,
              "thumbnailColorHex": null,
              "mediaDescription": null,
              "summaryBullets": null,
              "extracts": null,
              "processingStatus": "pending",
              "processingDetail": null,
              "lastProcessedChunk": 0,
              "failureReason": null,
              "isArchived": false,
              "archivedAt": null,
              "tags": []
            }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let result = try LibraryBackupService.importData(data, policy: .replace, into: context)
        XCTAssertEqual(result.importedCount, 1)

        let imported = try context.fetch(FetchDescriptor<ContentItem>())
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.id.uuidString.lowercased(), itemID)

        let highlights = try context.fetch(FetchDescriptor<Highlight>())
        XCTAssertTrue(highlights.isEmpty)
    }

    func testFutureFormatVersionThrows() throws {
        let json = """
        {
          "formatVersion": 3,
          "exportedAt": "2020-05-15T12:00:00.000Z",
          "appBuild": null,
          "items": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        XCTAssertThrowsError(try LibraryBackupService.importData(data, policy: .replace, into: context)) { error in
            guard let backupError = error as? LibraryBackupService.BackupError else {
                XCTFail("expected BackupError, got \(error)")
                return
            }
            guard case .unsupportedFormatVersion(let v) = backupError else {
                XCTFail("expected unsupportedFormatVersion, got \(backupError)")
                return
            }
            XCTAssertEqual(v, 3)
        }
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = PhathomModelContainer.currentSchema
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
