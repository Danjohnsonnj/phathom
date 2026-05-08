import Foundation
import SwiftData

@Model
public final class ContentItem {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var title: String?
    /// `true` when the user manually entered/edited the title; the scrape pipeline must not overwrite it.
    public var titleUserSet: Bool = false
    public var originalURL: URL?
    public var displayHost: String?
    public var contentKind: String
    public var rawText: String?
    /// Markdown derived from generic web HTML at scrape time; Detail Source only; LLM/search use `rawText`.
    public var sourceMarkdown: String?
    public var thumbnailData: Data?
    public var thumbnailColorHex: String?
    public var mediaDescription: String?
    public var summaryBullets: String?
    public var extracts: String?
    public var processingStatus: String = ProcessingStatus.pending.rawValue
    public var processingDetail: String?
    public var lastProcessedChunk: Int = 0
    public var failureReason: String?
    public var isArchived: Bool = false
    public var archivedAt: Date? = nil
    /// User-facing triage status (`new` / `read` / `filed`). Stored as raw string so SwiftData can
    /// apply a lightweight migration on existing rows: missing values materialize as `"new"`.
    public var readStatus: String = ReadStatus.new.rawValue
    @Relationship(deleteRule: .nullify) public var tags: [Tag] = []

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        contentKind: ContentKind = .web,
        originalURL: URL? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.contentKind = contentKind.rawValue
        self.originalURL = originalURL
        self.displayHost = originalURL?.host
        self.thumbnailColorHex = ContentItem.deterministicColor(from: id)
    }

    nonisolated private static let thumbnailHexCycle: [String] = [
        "#eb5e28", "#403d39", "#ccc5b9", "#252422",
        "#5c534c", "#8b4a2c", "#6b6560", "#3d3a37",
    ]

    nonisolated public static func deterministicColor(from uuid: UUID) -> String {
        let sum = withUnsafeBytes(of: uuid) { buffer in
            buffer.reduce(0) { $0 + Int($1) }
        }
        let idx = abs(sum) % thumbnailHexCycle.count
        return thumbnailHexCycle[idx]
    }
}

public extension ContentItem {
    var kind: ContentKind { ContentKind(rawValue: contentKind) ?? .web }

    var status: ProcessingStatus { ProcessingStatus(rawValue: processingStatus) ?? .pending }

    var readState: ReadStatus { ReadStatus(rawValue: readStatus) ?? .new }

    /// Tag display names in relationship order (same as `tags.map(\.name)`).
    var tagNames: [String] { tags.map(\.name) }

    var displayTitle: String {
        if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        switch kind {
        case .web:
            return displayHost ?? originalURL?.host ?? "Untitled"
        case .media:
            return "Photo"
        case .note:
            return "Untitled"
        }
    }
}
