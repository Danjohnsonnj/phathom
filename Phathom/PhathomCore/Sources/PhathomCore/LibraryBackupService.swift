import Foundation
import SwiftData

public enum LibraryBackupService {
    public static let currentFormatVersion = 5

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

    public struct FocusEntryRecord: Codable, Sendable {
        public var id: UUID
        public var addedAt: Date
        public var sortOrder: Int
        public var lastTouchedAt: Date

        public init(id: UUID, addedAt: Date, sortOrder: Int, lastTouchedAt: Date) {
            self.id = id
            self.addedAt = addedAt
            self.sortOrder = sortOrder
            self.lastTouchedAt = lastTouchedAt
        }
    }

    public struct FocusOutcomeRecord: Codable, Sendable {
        public var id: UUID
        public var completedAt: Date
        public var outcomeKind: String
        public var takeawayText: String?
        public var linkedHighlightID: UUID?
        public var scheduledResurfaceAt: Date?

        public init(
            id: UUID,
            completedAt: Date,
            outcomeKind: String,
            takeawayText: String? = nil,
            linkedHighlightID: UUID? = nil,
            scheduledResurfaceAt: Date? = nil
        ) {
            self.id = id
            self.completedAt = completedAt
            self.outcomeKind = outcomeKind
            self.takeawayText = takeawayText
            self.linkedHighlightID = linkedHighlightID
            self.scheduledResurfaceAt = scheduledResurfaceAt
        }
    }

    public struct HighlightRecord: Codable, Sendable {
        public var id: UUID
        public var createdAt: Date
        public var sourceMarkdownOffset: Int
        public var sourceMarkdownLength: Int
        public var sourceMarkdownSegmentsJSON: String?
        public var quotedText: String
        public var userNote: String?

        public init(
            id: UUID,
            createdAt: Date,
            sourceMarkdownOffset: Int,
            sourceMarkdownLength: Int,
            quotedText: String,
            userNote: String? = nil,
            sourceMarkdownSegmentsJSON: String? = nil
        ) {
            self.id = id
            self.createdAt = createdAt
            self.sourceMarkdownOffset = sourceMarkdownOffset
            self.sourceMarkdownLength = sourceMarkdownLength
            self.sourceMarkdownSegmentsJSON = sourceMarkdownSegmentsJSON
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
        public var userAddedTagNames: [String]
        public var highlights: [HighlightRecord]
        public var categoryName: String?
        public var focusEntry: FocusEntryRecord?
        public var focusOutcomes: [FocusOutcomeRecord]

        private enum CodingKeys: String, CodingKey {
            case id
            case createdAt
            case title
            case titleUserSet
            case originalURL
            case displayHost
            case contentKind
            case rawText
            case sourceMarkdown
            case thumbnailData
            case thumbnailColorHex
            case mediaDescription
            case summaryBullets
            case extracts
            case processingStatus
            case processingDetail
            case lastProcessedChunk
            case failureReason
            case isArchived
            case archivedAt
            case tags
            case userAddedTagNames
            case highlights
            case categoryName
            case focusEntry
            case focusOutcomes
        }

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
            userAddedTagNames: [String] = [],
            highlights: [HighlightRecord] = [],
            categoryName: String? = nil,
            focusEntry: FocusEntryRecord? = nil,
            focusOutcomes: [FocusOutcomeRecord] = []
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
            self.userAddedTagNames = userAddedTagNames
            self.highlights = highlights
            self.categoryName = categoryName
            self.focusEntry = focusEntry
            self.focusOutcomes = focusOutcomes
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(titleUserSet, forKey: .titleUserSet)
            try container.encodeIfPresent(originalURL, forKey: .originalURL)
            try container.encodeIfPresent(displayHost, forKey: .displayHost)
            try container.encode(contentKind, forKey: .contentKind)
            try container.encodeIfPresent(rawText, forKey: .rawText)
            try container.encodeIfPresent(sourceMarkdown, forKey: .sourceMarkdown)
            try container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
            try container.encodeIfPresent(thumbnailColorHex, forKey: .thumbnailColorHex)
            try container.encodeIfPresent(mediaDescription, forKey: .mediaDescription)
            try container.encodeIfPresent(summaryBullets, forKey: .summaryBullets)
            try container.encodeIfPresent(extracts, forKey: .extracts)
            try container.encode(processingStatus, forKey: .processingStatus)
            try container.encodeIfPresent(processingDetail, forKey: .processingDetail)
            try container.encode(lastProcessedChunk, forKey: .lastProcessedChunk)
            try container.encodeIfPresent(failureReason, forKey: .failureReason)
            try container.encode(isArchived, forKey: .isArchived)
            try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
            try container.encode(tags, forKey: .tags)
            try container.encode(userAddedTagNames, forKey: .userAddedTagNames)
            try container.encode(highlights, forKey: .highlights)
            try container.encodeIfPresent(categoryName, forKey: .categoryName)
            try container.encodeIfPresent(focusEntry, forKey: .focusEntry)
            try container.encode(focusOutcomes, forKey: .focusOutcomes)
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
            userAddedTagNames = try container.decodeIfPresent([String].self, forKey: .userAddedTagNames) ?? []
            highlights = try container.decodeIfPresent([HighlightRecord].self, forKey: .highlights) ?? []
            categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
            focusEntry = try container.decodeIfPresent(FocusEntryRecord.self, forKey: .focusEntry)
            focusOutcomes = try container.decodeIfPresent([FocusOutcomeRecord].self, forKey: .focusOutcomes) ?? []
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
        case focusCapExceeded(activeCount: Int, maxAllowed: Int)
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
            case .focusCapExceeded(let activeCount, let maxAllowed):
                return "Backup would exceed Focus stack cap: \(activeCount) active entries (max \(maxAllowed))."
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
            case .focusCapExceeded(let activeCount, let maxAllowed):
                return "code=focus_cap_exceeded activeCount=\(activeCount) maxAllowed=\(maxAllowed)"
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
                    userNote: h.userNote,
                    sourceMarkdownSegmentsJSON: h.sourceMarkdownSegmentsJSON
                )
            }
            let focusEntryRecord: FocusEntryRecord? = item.focusEntry.map { entry in
                FocusEntryRecord(
                    id: entry.id,
                    addedAt: entry.addedAt,
                    sortOrder: entry.sortOrder,
                    lastTouchedAt: entry.lastTouchedAt
                )
            }
            let outcomeRecords = item.focusOutcomes.map { outcome in
                FocusOutcomeRecord(
                    id: outcome.id,
                    completedAt: outcome.completedAt,
                    outcomeKind: outcome.outcomeKind,
                    takeawayText: outcome.takeawayText,
                    linkedHighlightID: outcome.linkedHighlightID,
                    scheduledResurfaceAt: outcome.scheduledResurfaceAt
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
                userAddedTagNames: TagProvenanceNormalizer.normalizeMany(item.userAddedTagNames),
                highlights: hlRecords,
                categoryName: item.category?.name,
                focusEntry: focusEntryRecord,
                focusOutcomes: outcomeRecords
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
            let categoryDescriptor = FetchDescriptor<Category>()
            let allCategories = try modelContext.fetch(categoryDescriptor)
            for category in allCategories {
                modelContext.delete(category)
            }
            try modelContext.save()
            DispatchQueue.main.async {
                LibraryContentChangeNotifier.postLibraryContentDidChange()
            }
            existingItems = []
        }

        var existingByID = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
        var tagsByName = try existingTagsByName(from: modelContext)
        var categoriesByName = try existingCategoriesByName(from: modelContext)

        try validateFocusCap(
            envelope: envelope,
            policy: policy,
            existingItems: existingItems
        )

        for record in envelope.items {
            if policy == .merge, existingByID[record.id] != nil {
                skipped += 1
                continue
            }
            let item = makeContentItem(
                from: record,
                tagIndex: &tagsByName,
                categoryIndex: &categoriesByName,
                modelContext: modelContext
            )
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
            for (outcomeIndex, outcome) in item.focusOutcomes.enumerated() {
                if FocusOutcomeKind(rawValue: outcome.outcomeKind) == nil {
                    throw BackupError.invalidItem(
                        index: index,
                        reason: "focusOutcomes[\(outcomeIndex)].outcomeKind '\(outcome.outcomeKind)' is not supported"
                    )
                }
            }
        }

        return envelope
    }

    private static func validateFocusCap(
        envelope: ExportEnvelope,
        policy: ImportPolicy,
        existingItems: [ContentItem]
    ) throws {
        let maxAllowed = FocusStackConstants.maxActiveEntries
        let projected: Int
        switch policy {
        case .replace:
            projected = envelope.items.filter { $0.focusEntry != nil && !$0.isArchived }.count
        case .merge:
            let existingIDs = Set(existingItems.map(\.id))
            let retainedActive = existingItems.filter { $0.focusEntry != nil && !$0.isArchived }.count
            let incomingActive = envelope.items.filter { record in
                record.focusEntry != nil
                    && !record.isArchived
                    && !existingIDs.contains(record.id)
            }.count
            projected = retainedActive + incomingActive
        }
        guard projected <= maxAllowed else {
            throw BackupError.focusCapExceeded(activeCount: projected, maxAllowed: maxAllowed)
        }
    }

    private static func existingTagsByName(from modelContext: ModelContext) throws -> [String: Tag] {
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        var index: [String: Tag] = [:]
        for tag in tags {
            index[tag.name] = tag
        }
        return index
    }

    private static func existingCategoriesByName(from modelContext: ModelContext) throws -> [String: Category] {
        let categories = try modelContext.fetch(FetchDescriptor<Category>())
        var index: [String: Category] = [:]
        for category in categories {
            index[category.name] = category
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
        categoryIndex: inout [String: Category],
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

        item.userAddedTagNames = TagProvenanceNormalizer.normalizeMany(record.userAddedTagNames)
        TagRelationshipUpsert.attachMissingTagNames(
            item.userAddedTagNames,
            to: item,
            tagIndex: &tagIndex,
            context: modelContext
        )

        if let rawCat = record.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawCat.isEmpty,
           let normalizedCat = CategoryDisplayFormatter.normalize(rawCat)
        {
            if let existing = categoryIndex[normalizedCat] {
                item.category = existing
            } else {
                let newCategory = Category(name: normalizedCat)
                modelContext.insert(newCategory)
                categoryIndex[normalizedCat] = newCategory
                item.category = newCategory
            }
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
                userNote: hr.userNote,
                sourceMarkdownSegmentsJSON: hr.sourceMarkdownSegmentsJSON
            )
            highlight.id = hr.id
            highlight.createdAt = hr.createdAt
            highlight.item = item
            modelContext.insert(highlight)
        }

        for foRecord in record.focusOutcomes {
            guard let kind = FocusOutcomeKind(rawValue: foRecord.outcomeKind) else { continue }
            let outcome = FocusOutcome(
                contentItem: item,
                kind: kind,
                completedAt: foRecord.completedAt,
                takeawayText: foRecord.takeawayText,
                linkedHighlightID: foRecord.linkedHighlightID,
                scheduledResurfaceAt: foRecord.scheduledResurfaceAt
            )
            outcome.id = foRecord.id
            modelContext.insert(outcome)
        }

        if let feRecord = record.focusEntry, !record.isArchived {
            let entry = FocusEntry(contentItem: item, sortOrder: feRecord.sortOrder, now: feRecord.addedAt)
            entry.id = feRecord.id
            entry.lastTouchedAt = feRecord.lastTouchedAt
            modelContext.insert(entry)
        }

        return item
    }
}
