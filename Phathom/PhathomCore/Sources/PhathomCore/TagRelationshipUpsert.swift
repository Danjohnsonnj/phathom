import Foundation
import SwiftData

/// Creates or reuses `Tag` rows and appends missing names to `item.tags`.
public enum TagRelationshipUpsert {
    public static func attachMissingTagNames(
        _ names: [String],
        to item: ContentItem,
        tagIndex: inout [String: Tag],
        context: ModelContext
    ) {
        let unique = TagNameNormalizer.normalize(many: names)
        guard !unique.isEmpty else { return }

        for name in unique {
            guard !item.tags.contains(where: { $0.name == name }) else { continue }

            let tag: Tag
            if let existing = tagIndex[name] {
                tag = existing
            } else {
                let created = Tag(name: name)
                context.insert(created)
                tagIndex[name] = created
                tag = created
            }
            item.tags.append(tag)
        }
    }
}
