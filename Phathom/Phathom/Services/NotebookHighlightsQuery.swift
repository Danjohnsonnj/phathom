import Foundation
import PhathomCore

enum NotebookHighlightsQuery {
    struct ItemGroup: Identifiable {
        let item: ContentItem
        let highlights: [Highlight]
        var id: UUID { item.id }
    }

    /// Highlights whose parent item exists and is not archived.
    static func qualifyingHighlights(from all: [Highlight]) -> [Highlight] {
        all.filter { highlight in
            guard let item = highlight.item else { return false }
            return !item.isArchived
        }
    }

    /// Groups qualifying highlights by parent item; items ordered by latest highlight `createdAt` desc;
    /// highlights within each item follow `ContentItem.highlightsSortedByOffset`.
    ///
    /// Filter sets: `nil` per dimension = pass-through (all values). Category tokens include ``LibraryCategoryFilterStorage/uncategorizedRaw``.
    static func groups(
        from allHighlights: [Highlight],
        filterKinds: Set<ContentKind>? = nil,
        filterStatuses: Set<ReadStatus>? = nil,
        filterCategories: Set<String>? = nil
    ) -> [ItemGroup] {
        var seenItemIDs = Set<UUID>()
        var items: [ContentItem] = []

        for highlight in qualifyingHighlights(from: allHighlights) {
            guard let item = highlight.item else { continue }
            if seenItemIDs.insert(item.id).inserted {
                items.append(item)
            }
        }

        items = TagRelationService.itemsFilteredByKindStatusAndCategory(
            items: items,
            filterKinds: filterKinds,
            filterStatuses: filterStatuses,
            filterCategories: filterCategories
        )

        return items
            .map { item in
                ItemGroup(item: item, highlights: item.highlightsSortedByOffset)
            }
            .filter { !$0.highlights.isEmpty }
            .sorted { latestHighlightDate($0) > latestHighlightDate($1) }
    }

    private static func latestHighlightDate(_ group: ItemGroup) -> Date {
        group.highlights.map(\.createdAt).max() ?? .distantPast
    }
}
