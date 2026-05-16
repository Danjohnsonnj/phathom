import Foundation
import SwiftData

@Model
public final class Category {
    @Attribute(.unique) public var name: String
    public var createdAt: Date = Date()
    @Relationship(inverse: \ContentItem.category)
    public var items: [ContentItem] = []

    public init(name: String) {
        self.name = name
    }
}
