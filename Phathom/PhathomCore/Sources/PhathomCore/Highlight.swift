import Foundation
import SwiftData

@Model
public final class Highlight {
    @Attribute(.unique) public var id: UUID = UUID()
    public var createdAt: Date = Date()
    /// UTF-16 start offset into canonical stored `ContentItem.sourceMarkdown`.
    /// Default `0` lets Core Data lightweight migration backfill existing rows before one-shot highlight wipe runs.
    public var sourceMarkdownOffset: Int = 0
    /// UTF-16 length in canonical stored `ContentItem.sourceMarkdown`.
    /// Default `0` lets Core Data lightweight migration backfill existing rows before one-shot highlight wipe runs.
    public var sourceMarkdownLength: Int = 0
    /// JSON array of `{start,end}` UTF-16 segment bounds for precise WKWebView overlay re-apply.
    public var sourceMarkdownSegmentsJSON: String?
    /// Verbatim snapshot for Highlights list and note sheet.
    public var quotedText: String
    public var userNote: String?

    @Relationship(inverse: \ContentItem.highlights) public var item: ContentItem?

    public init(
        sourceMarkdownOffset: Int,
        sourceMarkdownLength: Int,
        quotedText: String,
        userNote: String? = nil,
        sourceMarkdownSegmentsJSON: String? = nil
    ) {
        self.sourceMarkdownOffset = sourceMarkdownOffset
        self.sourceMarkdownLength = sourceMarkdownLength
        self.sourceMarkdownSegmentsJSON = sourceMarkdownSegmentsJSON
        self.quotedText = quotedText
        self.userNote = userNote
    }
}

/// `Identifiable` / `.sheet(item:)` rely on stable `id`; keep `@Attribute(.unique)` on `id`.
extension Highlight: Identifiable {}
