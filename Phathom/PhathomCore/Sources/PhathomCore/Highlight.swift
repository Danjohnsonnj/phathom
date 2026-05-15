import Foundation
import SwiftData

@Model
public final class Highlight {
    @Attribute(.unique) public var id: UUID = UUID()
    public var createdAt: Date = Date()
    /// UTF-16 start offset into canonical stored `ContentItem.sourceMarkdown`.
    public var sourceMarkdownOffset: Int
    /// UTF-16 length in canonical stored `sourceMarkdown`.
    public var sourceMarkdownLength: Int
    /// Verbatim snapshot for Highlights list and note sheet.
    public var quotedText: String
    public var userNote: String?

    @Relationship(inverse: \ContentItem.highlights) public var item: ContentItem?

    public init(
        sourceMarkdownOffset: Int,
        sourceMarkdownLength: Int,
        quotedText: String,
        userNote: String? = nil
    ) {
        self.sourceMarkdownOffset = sourceMarkdownOffset
        self.sourceMarkdownLength = sourceMarkdownLength
        self.quotedText = quotedText
        self.userNote = userNote
    }
}

/// `Identifiable` / `.sheet(item:)` rely on stable `id`; keep `@Attribute(.unique)` on `id`.
extension Highlight: Identifiable {}
