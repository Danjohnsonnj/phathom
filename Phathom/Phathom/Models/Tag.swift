import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \ContentItem.tags) var items: [ContentItem] = []

    init(name: String) {
        self.name = name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
