import Foundation
import SwiftData

@Model
public final class Tag {
    @Attribute(.unique) public var name: String
    @Relationship(inverse: \ContentItem.tags) public var items: [ContentItem] = []

    public init(name: String) {
        self.name = name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
