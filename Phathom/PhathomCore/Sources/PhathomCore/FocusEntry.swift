import Foundation
import SwiftData

@Model
public final class FocusEntry {
    @Attribute(.unique) public var id: UUID
    public var addedAt: Date
    public var sortOrder: Int
    public var lastTouchedAt: Date

    @Relationship(inverse: \ContentItem.focusEntry)
    public var contentItem: ContentItem?

    public init(contentItem: ContentItem, sortOrder: Int, now: Date = .now) {
        self.id = UUID()
        self.contentItem = contentItem
        self.addedAt = now
        self.sortOrder = sortOrder
        self.lastTouchedAt = now
    }
}

extension FocusEntry: Identifiable {}
