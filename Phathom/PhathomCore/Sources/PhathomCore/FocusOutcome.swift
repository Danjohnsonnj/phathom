import Foundation
import SwiftData

@Model
public final class FocusOutcome {
    @Attribute(.unique) public var id: UUID
    public var completedAt: Date
    public var outcomeKind: String

    public var takeawayText: String?
    public var linkedHighlightID: UUID?
    public var scheduledResurfaceAt: Date?

    @Relationship(inverse: \ContentItem.focusOutcomes)
    public var contentItem: ContentItem?

    public init(
        contentItem: ContentItem,
        kind: FocusOutcomeKind,
        completedAt: Date = .now,
        takeawayText: String? = nil,
        linkedHighlightID: UUID? = nil,
        scheduledResurfaceAt: Date? = nil
    ) {
        self.id = UUID()
        self.contentItem = contentItem
        self.completedAt = completedAt
        self.outcomeKind = kind.rawValue
        self.takeawayText = takeawayText
        self.linkedHighlightID = linkedHighlightID
        self.scheduledResurfaceAt = scheduledResurfaceAt
    }
}

public extension FocusOutcome {
    var kind: FocusOutcomeKind {
        FocusOutcomeKind(rawValue: outcomeKind) ?? .release
    }
}
