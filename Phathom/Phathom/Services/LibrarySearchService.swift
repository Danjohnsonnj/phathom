import PhathomCore
import Foundation

/// Library search bucketing — driven by the Library search box. Adjacent semantics and Dive deeper Llama expansion
/// are implemented in ``TagRelationService``.
///
/// **Stage 1 (sync, fast)**:
///   - `matching`: substring filter across title, raw text, host, URL, media description, tags, and highlight user notes
///     (preserves the previous `LibraryTab.filteredItems` behavior so we don't regress discovery).
///   - `adjacent`: only when the trimmed query equals a known tag name (case-insensitive). Returns
///     items that do NOT contain the resolved tag but share at least one tag with any **anchor** item:
///     either a substring-matching item, or — when matching is empty — any item that carries the
///     resolved tag (library filter still applies). Ranked by max Jaccard vs anchors, capped at 8.
///
/// **Stage 2 (async, "Dive deeper")** lives in `LibraryTab` and calls `diveDeeper(...)` below,
/// which delegates to ``TagRelationService.expandAndRankAdjacent``. On any failure the Stage 1 adjacent order is preserved.
enum LibrarySearchService {
    static let adjacentCandidateLimit = TagRelationService.adjacentCandidateLimit

    struct Sections {
        let matching: [ContentItem]
        let adjacent: [ContentItem]
        /// Lowercased name of the tag the query resolved to, when the trimmed query exactly matches
        /// any tag on the candidate items. `nil` means the adjacent section should be hidden.
        let resolvedTagName: String?

        static let empty = Sections(matching: [], adjacent: [], resolvedTagName: nil)

        var isEmpty: Bool { matching.isEmpty && adjacent.isEmpty }
    }

    /// Partition `items` for the Library list. Callers pass the already-loaded `@Query` snapshot;
    /// kind / status filtering happens here so adjacency respects the active filter selection.
    static func bucket(
        query: String,
        items: [ContentItem],
        filterKind: ContentKind?,
        filterStatus: ReadStatus? = nil,
        filterCategory: String? = nil
    ) -> Sections {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            let pool = TagRelationService.itemsFilteredByKindStatusAndCategory(
                items: items,
                filterKind: filterKind,
                filterStatus: filterStatus,
                filterCategory: filterCategory
            )
            return Sections(matching: pool, adjacent: [], resolvedTagName: nil)
        }

        let tagIndexWrapped = TagRelationService.buildTagIndex(
            items: items,
            filterKind: filterKind,
            filterStatus: filterStatus,
            filterCategory: filterCategory
        )
        let kindFiltered = tagIndexWrapped.filteredItems
        let tagIndex = tagIndexWrapped.inverted

        let matching = kindFiltered.filter { item in
            let titleMatch = item.displayTitle.lowercased().contains(normalized)
            let rawTextMatch = (item.rawText ?? "").lowercased().contains(normalized)
            let hostMatch = (item.displayHost ?? "").lowercased().contains(normalized)
            let urlMatch = (item.originalURL?.absoluteString ?? "").lowercased().contains(normalized)
            let mediaMatch = (item.mediaDescription ?? "").lowercased().contains(normalized)
            let tagsMatch = item.tagNames.joined(separator: " ").lowercased().contains(normalized)
            let highlightNoteMatch = item.highlights.contains { highlight in
                guard let note = highlight.userNote?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !note.isEmpty else { return false }
                return note.lowercased().contains(normalized)
            }
            return titleMatch || rawTextMatch || hostMatch || urlMatch || mediaMatch || tagsMatch || highlightNoteMatch
        }

        let resolvedTagName: String? = tagIndex[normalized] != nil ? normalized : nil

        let adjacent: [ContentItem]
        if let resolvedTag = resolvedTagName {
            let anchorItems: [ContentItem]
            if !matching.isEmpty {
                anchorItems = matching
            } else {
                anchorItems = tagIndex[resolvedTag] ?? []
            }
            if anchorItems.isEmpty {
                adjacent = []
            } else {
                adjacent = TagRelationService.computeAdjacent(
                    resolvedTags: [resolvedTag],
                    anchorItems: anchorItems,
                    excludeIDs: [],
                    inverted: tagIndex
                )
            }
        } else {
            adjacent = []
        }

        return Sections(matching: matching, adjacent: adjacent, resolvedTagName: resolvedTagName)
    }

    /// "Dive deeper": semantic + prefix tag expansion via Llama, then expanded adjacent + `rankAdjacentItems`.
    ///
    /// On any error (no model, parse error, cancellation), returns the original `sections.adjacent`
    /// so the UI keeps its Stage 1 ranking.
    static func diveDeeper(
        query: String,
        sections: Sections,
        allItems: [ContentItem],
        filterKind: ContentKind?,
        filterStatus: ReadStatus? = nil,
        filterCategory: String? = nil
    ) async -> [ContentItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return sections.adjacent }

        let tagIndexWrapped = TagRelationService.buildTagIndex(
            items: allItems,
            filterKind: filterKind,
            filterStatus: filterStatus,
            filterCategory: filterCategory
        )
        guard !tagIndexWrapped.vocabulary.isEmpty else { return sections.adjacent }

        let prefixResolved = TagRelationService.prefixResolvedTags(
            query: normalized,
            vocabulary: tagIndexWrapped.vocabulary,
            seedTag: sections.resolvedTagName
        )

        return await TagRelationService.expandAndRankAdjacent(
            semanticQuery: normalized,
            tappedTagForRanking: sections.resolvedTagName ?? normalized,
            sourceTagsLLMContext: .alignedWithExpandedResolvedTags,
            tagIndex: tagIndexWrapped,
            initialPrefixResolved: prefixResolved,
            excludeIDsFromMatchingSection: Set(sections.matching.map(\.id)),
            allItemsForLookup: allItems,
            stage1Adjacent: sections.adjacent
        )
    }
}
