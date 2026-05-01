import Foundation
import SwiftData

@Model
final class ContentItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String?
    var originalURL: URL?
    var displayHost: String?
    var contentKind: String
    var rawText: String?
    var thumbnailData: Data?
    var thumbnailColorHex: String?
    var mediaDescription: String?
    var summaryBullets: String?
    var extracts: String?
    var processingStatus: String = ProcessingStatus.pending.rawValue
    var processingDetail: String?
    var lastProcessedChunk: Int = 0
    var failureReason: String?
    var isArchived: Bool = false
    /// Set when the user archives; cleared on restore. Used for the 48-hour retention window.
    var archivedAt: Date? = nil
    @Relationship(deleteRule: .nullify) var tags: [Tag] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        contentKind: ContentKind = .web,
        originalURL: URL? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.contentKind = contentKind.rawValue
        self.originalURL = originalURL
        self.displayHost = originalURL?.host()
        self.thumbnailColorHex = ContentItem.deterministicColor(from: id)
    }

    static func deterministicColor(from uuid: UUID) -> String {
        let colors = AppPalette.thumbnailHexCycle
        let sum = withUnsafeBytes(of: uuid) { buffer in
            buffer.reduce(0) { $0 + Int($1) }
        }
        let idx = abs(sum) % colors.count
        return colors[idx]
    }
}

extension ContentItem {
    var kind: ContentKind { ContentKind(rawValue: contentKind) ?? .web }

    var status: ProcessingStatus { ProcessingStatus(rawValue: processingStatus) ?? .pending }
}
