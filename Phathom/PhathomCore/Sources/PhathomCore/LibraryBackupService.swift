import Foundation
import SwiftData

public enum LibraryBackupService {
    public static let currentFormatVersion = 1

    public enum ImportPolicy: Sendable {
        case replace
        case merge
    }

    public struct ExportEnvelope: Codable, Sendable {
        public var formatVersion: Int
        public var exportedAt: Date
        public var appBuild: String?
        public var items: [ItemRecord]

        public init(
            formatVersion: Int = LibraryBackupService.currentFormatVersion,
            exportedAt: Date = Date(),
            appBuild: String?,
            items: [ItemRecord]
        ) {
            self.formatVersion = formatVersion
            self.exportedAt = exportedAt
            self.appBuild = appBuild
            self.items = items
        }
    }

    public struct ItemRecord: Codable, Sendable {
        public var id: UUID
        public var createdAt: Date
        public var title: String?
        public var titleUserSet: Bool
        public var originalURL: URL?
        public var displayHost: String?
        public var contentKind: String
        public var rawText: String?
        public var sourceMarkdown: String?
        public var thumbnailData: Data?
        public var thumbnailColorHex: String?
        public var mediaDescription: String?
        public var summaryBullets: String?
        public var extracts: String?
        public var processingStatus: String
        public var processingDetail: String?
        public var lastProcessedChunk: Int
        public var failureReason: String?
        public var isArchived: Bool
        public var archivedAt: Date?
        public var tags: [String]

        public init(
            id: UUID,
            createdAt: Date,
            title: String?,
            titleUserSet: Bool,
            originalURL: URL?,
            displayHost: String?,
            contentKind: String,
            rawText: String?,
            sourceMarkdown: String?,
            thumbnailData: Data?,
            thumbnailColorHex: String?,
            mediaDescription: String?,
            summaryBullets: String?,
            extracts: String?,
            processingStatus: String,
            processingDetail: String?,
            lastProcessedChunk: Int,
            failureReason: String?,
            isArchived: Bool,
            archivedAt: Date?,
            tags: [String]
        ) {
            self.id = id
            self.createdAt = createdAt
            self.title = title
            self.titleUserSet = titleUserSet
            self.originalURL = originalURL
            self.displayHost = displayHost
            self.contentKind = contentKind
            self.rawText = rawText
            self.sourceMarkdown = sourceMarkdown
            self.thumbnailData = thumbnailData
            self.thumbnailColorHex = thumbnailColorHex
            self.mediaDescription = mediaDescription
            self.summaryBullets = summaryBullets
            self.extracts = extracts
            self.processingStatus = processingStatus
            self.processingDetail = processingDetail
            self.lastProcessedChunk = lastProcessedChunk
            self.failureReason = failureReason
            self.isArchived = isArchived
            self.archivedAt = archivedAt
            self.tags = tags
        }
    }

    public struct ImportPreview: Sendable {
        public var itemCount: Int
        public var itemIDs: Set<UUID>

        public init(itemCount: Int, itemIDs: Set<UUID>) {
            self.itemCount = itemCount
            self.itemIDs = itemIDs
        }
    }

    public struct ImportResult: Sendable {
        public var importedCount: Int
        public var skippedDuplicateCount: Int
        public var existingCountBeforeImport: Int

        public init(importedCount: Int, skippedDuplicateCount: Int, existingCountBeforeImport: Int) {
            self.importedCount = importedCount
            self.skippedDuplicateCount = skippedDuplicateCount
            self.existingCountBeforeImport = existingCountBeforeImport
        }
    }

    public enum BackupError: Error, LocalizedError, Sendable {
        case emptyData
        case unsupportedFormatVersion(Int)
        case invalidItem(index: Int, reason: String)
        case duplicateItemIDs(UUID)
        case decodeFailure(String)
        case encodeFailure(String)

        public var errorDescription: String? {
            switch self {
            case .emptyData:
                return "Backup file is empty."
            case .unsupportedFormatVersion(let version):
                return "Unsupported backup format version: \(version)."
            case .invalidItem(let index, let reason):
                return "Invalid item at index \(index): \(reason)"
            case .duplicateItemIDs(let id):
                return "Backup contains duplicate item id: \(id.uuidString)"
            case .decodeFailure(let details):
                return "Failed to decode backup file: \(details)"
            case .encodeFailure(let details):
                return "Failed to encode backup data: \(details)"
            }
        }

        public var diagnosticText: String {
            switch self {
            case .emptyData:
                return "code=empty_data"
            case .unsupportedFormatVersion(let version):
                return "code=unsupported_format_version formatVersion=\(version) supported=\(LibraryBackupService.currentFormatVersion)"
            case .invalidItem(let index, let reason):
                return "code=invalid_item index=\(index) reason=\(reason)"
            case .duplicateItemIDs(let id):
                return "code=duplicate_item_id id=\(id.uuidString)"
            case .decodeFailure(let details):
                return "code=decode_failure details=\(details)"
            case .encodeFailure(let details):
                return "code=encode_failure details=\(details)"
            }
        }
    }

    public static func exportData(
        from modelContext: ModelContext,
        appBuild: String? = nil
    ) throws -> Data {
        let descriptor = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { $0.isArchived == false }
        )
        let items = try modelContext.fetch(descriptor)
        let records = items.map { item in
            ItemRecord(
                id: item.id,
                createdAt: item.createdAt,
                title: item.title,
                titleUserSet: item.titleUserSet,
                originalURL: item.originalURL,
                displayHost: item.displayHost,
                contentKind: item.contentKind,
                rawText: item.rawText,
                sourceMarkdown: item.sourceMarkdown,
                thumbnailData: item.thumbnailData,
                thumbnailColorHex: item.thumbnailColorHex,
                mediaDescription: item.mediaDescription,
                summaryBullets: item.summaryBullets,
                extracts: item.extracts,
                processingStatus: item.processingStatus,
                processingDetail: item.processingDetail,
                lastProcessedChunk: item.lastProcessedChunk,
                failureReason: item.failureReason,
                isArchived: item.isArchived,
                archivedAt: item.archivedAt,
                tags: item.tags.map(\.name)
            )
        }

        let envelope = ExportEnvelope(appBuild: appBuild, items: records)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(envelope)
        } catch {
            throw BackupError.encodeFailure(error.localizedDescription)
        }
    }

    public static func previewImport(data: Data) throws -> ImportPreview {
        let envelope = try decodeAndValidate(data: data)
        let ids = Set(envelope.items.map(\.id))
        return ImportPreview(itemCount: envelope.items.count, itemIDs: ids)
    }

    public static func importData(
        _ data: Data,
        policy: ImportPolicy,
        into modelContext: ModelContext
    ) throws -> ImportResult {
        let envelope = try decodeAndValidate(data: data)

        let existingDescriptor = FetchDescriptor<ContentItem>()
        var existingItems = try modelContext.fetch(existingDescriptor)
        let existingCount = existingItems.count
        var skipped = 0
        var imported = 0

        if policy == .replace {
            for item in existingItems {
                modelContext.delete(item)
            }
            let tagDescriptor = FetchDescriptor<Tag>()
            let allTags = try modelContext.fetch(tagDescriptor)
            for tag in allTags {
                modelContext.delete(tag)
            }
            try modelContext.save()
            existingItems = []
        }

        var existingByID = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
        var tagsByName = try existingTagsByName(from: modelContext)

        for record in envelope.items {
            if policy == .merge, existingByID[record.id] != nil {
                skipped += 1
                continue
            }
            let item = makeContentItem(from: record, tagIndex: &tagsByName, modelContext: modelContext)
            modelContext.insert(item)
            existingByID[item.id] = item
            imported += 1
        }

        try modelContext.save()
        return ImportResult(
            importedCount: imported,
            skippedDuplicateCount: skipped,
            existingCountBeforeImport: existingCount
        )
    }

    private static func decodeAndValidate(data: Data) throws -> ExportEnvelope {
        guard !data.isEmpty else {
            throw BackupError.emptyData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: ExportEnvelope
        do {
            envelope = try decoder.decode(ExportEnvelope.self, from: data)
        } catch {
            throw BackupError.decodeFailure(error.localizedDescription)
        }

        guard envelope.formatVersion == currentFormatVersion else {
            throw BackupError.unsupportedFormatVersion(envelope.formatVersion)
        }

        var seen = Set<UUID>()
        for (index, item) in envelope.items.enumerated() {
            if item.contentKind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw BackupError.invalidItem(index: index, reason: "contentKind is empty")
            }
            if ProcessingStatus(rawValue: item.processingStatus) == nil {
                throw BackupError.invalidItem(
                    index: index,
                    reason: "processingStatus '\(item.processingStatus)' is not supported"
                )
            }
            if !seen.insert(item.id).inserted {
                throw BackupError.duplicateItemIDs(item.id)
            }
        }

        return envelope
    }

    private static func existingTagsByName(from modelContext: ModelContext) throws -> [String: Tag] {
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        var index: [String: Tag] = [:]
        for tag in tags {
            index[tag.name] = tag
        }
        return index
    }

    private static func makeContentItem(
        from record: ItemRecord,
        tagIndex: inout [String: Tag],
        modelContext: ModelContext
    ) -> ContentItem {
        let baseKind = ContentKind(rawValue: record.contentKind) ?? .web
        let item = ContentItem(
            id: record.id,
            createdAt: record.createdAt,
            contentKind: baseKind,
            originalURL: record.originalURL
        )
        item.title = record.title
        item.titleUserSet = record.titleUserSet
        item.displayHost = record.displayHost
        item.contentKind = record.contentKind
        item.rawText = record.rawText
        item.sourceMarkdown = record.sourceMarkdown
        item.thumbnailData = record.thumbnailData
        item.thumbnailColorHex = record.thumbnailColorHex
        item.mediaDescription = record.mediaDescription
        item.summaryBullets = record.summaryBullets
        item.extracts = record.extracts
        item.processingStatus = record.processingStatus
        item.processingDetail = record.processingDetail
        item.lastProcessedChunk = record.lastProcessedChunk
        item.failureReason = record.failureReason
        item.isArchived = record.isArchived
        item.archivedAt = record.archivedAt

        item.tags = record.tags.map { rawName in
            let normalized = rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = tagIndex[normalized] {
                return existing
            }
            let newTag = Tag(name: normalized)
            modelContext.insert(newTag)
            tagIndex[normalized] = newTag
            return newTag
        }
        return item
    }
}
