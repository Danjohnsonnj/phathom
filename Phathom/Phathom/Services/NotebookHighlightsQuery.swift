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
    /// `filterCategory`: `nil` = All; otherwise kebab name or ``LibraryCategoryFilterStorage/uncategorizedRaw``.
    static func groups(
        from allHighlights: [Highlight],
        filterKind: ContentKind? = nil,
        filterStatus: ReadStatus? = nil,
        filterCategory: String? = nil
    ) -> [ItemGroup] {
        var seenItemIDs = Set<UUID>()
        var items: [ContentItem] = []

        for highlight in qualifyingHighlights(from: allHighlights) {
            guard let item = highlight.item else { continue }
            if seenItemIDs.insert(item.id).inserted {
                items.append(item)
            }
        }

        if filterKind != nil || filterStatus != nil || filterCategory != nil {
            items = TagRelationService.itemsFilteredByKindStatusAndCategory(
                items: items,
                filterKind: filterKind,
                filterStatus: filterStatus,
                filterCategory: filterCategory
            )
        }

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
