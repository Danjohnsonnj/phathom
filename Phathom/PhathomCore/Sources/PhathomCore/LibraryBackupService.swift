import Foundation
import SwiftData

public enum LibraryBackupService {
    public static let currentFormatVersion = 2

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

    public struct HighlightRecord: Codable, Sendable {
        public var id: UUID
        public var createdAt: Date
        public var sourceMarkdownOffset: Int
        public var sourceMarkdownLength: Int
        public var quotedText: String
        public var userNote: String?

        public init(
            id: UUID,
            createdAt: Date,
            sourceMarkdownOffset: Int,
            sourceMarkdownLength: Int,
            quotedText: String,
            userNote: String? = nil
        ) {
            self.id = id
            self.createdAt = createdAt
            self.sourceMarkdownOffset = sourceMarkdownOffset
            self.sourceMarkdownLength = sourceMarkdownLength
            self.quotedText = quotedText
            self.userNote = userNote
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
        public var highlights: [HighlightRecord]

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
            tags: [String],
            highlights: [HighlightRecord] = []
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
            self.highlights = highlights
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            titleUserSet = try container.decode(Bool.self, forKey: .titleUserSet)
            originalURL = try container.decodeIfPresent(URL.self, forKey: .originalURL)
            displayHost = try container.decodeIfPresent(String.self, forKey: .displayHost)
            contentKind = try container.decode(String.self, forKey: .contentKind)
            rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
            sourceMarkdown = try container.decodeIfPresent(String.self, forKey: .sourceMarkdown)
            thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
            thumbnailColorHex = try container.decodeIfPresent(String.self, forKey: .thumbnailColorHex)
            mediaDescription = try container.decodeIfPresent(String.self, forKey: .mediaDescription)
            summaryBullets = try container.decodeIfPresent(String.self, forKey: .summaryBullets)
            extracts = try container.decodeIfPresent(String.self, forKey: .extracts)
            processingStatus = try container.decode(String.self, forKey: .processingStatus)
            processingDetail = try container.decodeIfPresent(String.self, forKey: .processingDetail)
            lastProcessedChunk = try container.decode(Int.self, forKey: .lastProcessedChunk)
            failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
            isArchived = try container.decode(Bool.self, forKey: .isArchived)
            archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
            tags = try container.decode([String].self, forKey: .tags)
            highlights = try container.decodeIfPresent([HighlightRecord].self, forKey: .highlights) ?? []
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
                return "code=unsupported_format_version formatVersion=\(version) maxSupported=\(LibraryBackupService.currentFormatVersion)"
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
            let hlRecords = item.highlights.map { h in
                HighlightRecord(
                    id: h.id,
                    createdAt: h.createdAt,
                    sourceMarkdownOffset: h.sourceMarkdownOffset,
                    sourceMarkdownLength: h.sourceMarkdownLength,
                    quotedText: h.quotedText,
                    userNote: h.userNote
                )
            }
            return ItemRecord(
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
                tags: item.tags.map(\.name),
                highlights: hlRecords
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
            DispatchQueue.main.async {
                LibraryContentChangeNotifier.postLibraryContentDidChange()
            }
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
        DispatchQueue.main.async {
            LibraryContentChangeNotifier.postLibraryContentDidChange()
        }
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

        guard envelope.formatVersion <= currentFormatVersion else {
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

    private static func shouldImportHighlight(_ hr: HighlightRecord, sourceMarkdown: String?) -> Bool {
        guard let md = sourceMarkdown, !md.isEmpty else { return false }
        guard hr.sourceMarkdownOffset >= 0, hr.sourceMarkdownLength > 0 else { return false }
        let end = hr.sourceMarkdownOffset + hr.sourceMarkdownLength
        guard end <= md.utf16.count else { return false }
        guard !hr.quotedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
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

        for hr in record.highlights {
            guard shouldImportHighlight(hr, sourceMarkdown: item.sourceMarkdown) else {
                #if DEBUG
                print("[LibraryBackupService] skipped invalid highlight import id=\(hr.id)")
                #endif
                continue
            }
            let highlight = Highlight(
                sourceMarkdownOffset: hr.sourceMarkdownOffset,
                sourceMarkdownLength: hr.sourceMarkdownLength,
                quotedText: hr.quotedText,
                userNote: hr.userNote
            )
            highlight.id = hr.id
            highlight.createdAt = hr.createdAt
            highlight.item = item
            modelContext.insert(highlight)
        }

        return item
    }
}
