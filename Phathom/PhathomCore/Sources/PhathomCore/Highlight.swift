import Foundation
import SwiftData

@Model
public final class Highlight {
    /// Bump `MarkdownStripper.algorithmVersion` when strip rules change; offsets in `plainTextOffset` / `plainTextLength` are only valid for matching version.
    public var markdownStripperVersion: Int = 1
    @Attribute(.unique) public var id: UUID = UUID()
    public var createdAt: Date = Date()
    /// UTF-16 start offset in stripped plain text (`ContentItem.strippedSourceText`).
    public var plainTextOffset: Int
    /// UTF-16 length in stripped plain text.
    public var plainTextLength: Int
    /// Verbatim snapshot for Highlights list and note sheet.
    public var quotedText: String
    public var userNote: String?

    @Relationship(inverse: \ContentItem.highlights) public var item: ContentItem?

    public init(
        plainTextOffset: Int,
        plainTextLength: Int,
        quotedText: String,
        userNote: String? = nil,
        markdownStripperVersion: Int = MarkdownStripper.algorithmVersion
    ) {
        self.markdownStripperVersion = markdownStripperVersion
        self.plainTextOffset = plainTextOffset
        self.plainTextLength = plainTextLength
        self.quotedText = quotedText
        self.userNote = userNote
    }
}

/// `Identifiable` / `.sheet(item:)` rely on stable `id`; keep `@Attribute(.unique)` on `id`.
extension Highlight: Identifiable {}
