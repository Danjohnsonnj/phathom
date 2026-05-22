import PhathomCore
import Foundation

/// Tag-tap related-items pipeline (`RelatedItemsSheet`).
///
/// Stage 1 (sync): exact matches (all other carriers of the tapped tag) + adjacent items discovered like
/// library Dive deeper (`TagRelationService`): prefix-expanded resolved tags, inverted-index expansion, Jaccard cap 8.
///
/// Stage 2 (async): Llama semantic widening + `rankAdjacentItems` inside one session; source tag context stays
/// the **source item’s** tag list per product contract (`TagRelationService.LLMSourceTagsContext.sourceItem`).
enum RelatedItemsService {
    static var adjacentCandidateLimit: Int { TagRelationService.adjacentCandidateLimit }

    struct Buckets {
        let exactMatches: [ContentItem]
        let adjacentCandidates: [ContentItem]
    }

    /// Build exact + Stage 1 adjacent for a tag tap. `allItems` is the caller’s `@Query` (non-archived).
    static func bucketsForTagTap(
        sourceItem: ContentItem,
        tappedTag: Tag,
        in allItems: [ContentItem]
    ) -> Buckets {
        let tappedName = tappedTag.name.lowercased()
        let vocabIndex = TagRelationService.buildTagIndex(
            items: allItems,
            filterKind: nil,
            filterStatus: nil,
            filterCategory: nil
        )

        let exact = TagRelationService.exactMatchesOtherThanSource(
            tappedTagName: tappedName,
            in: allItems,
            excludingSourceID: sourceItem.id
        )
        let excludeIDs = Set<UUID>([sourceItem.id]).union(exact.map(\.id))

        let resolvedSync = TagRelationService.prefixResolvedTags(
            query: tappedName,
            vocabulary: vocabIndex.vocabulary,
            seedTag: tappedName
        )

        let adjacent = TagRelationService.computeAdjacentFromResolvedTags(
            resolvedTags: resolvedSync,
            inverted: vocabIndex.inverted,
            excludeIDs: excludeIDs
        )

        return Buckets(exactMatches: exact, adjacentCandidates: adjacent)
    }

    /// Stage 2 semantic expansion + rerank. On failure returns `stage1Adjacent`.
    static func rankedAdjacentAfterExpansion(
        sourceItem: ContentItem,
        tappedTag: Tag,
        in allItems: [ContentItem],
        exactMatchIDs: Set<UUID>,
        stage1Adjacent: [ContentItem]
    ) async -> [ContentItem] {
        let tappedName = tappedTag.name.lowercased()
        let tagIndex = TagRelationService.buildTagIndex(
            items: allItems,
            filterKind: nil,
            filterStatus: nil,
            filterCategory: nil
        )

        let prefixResolved = TagRelationService.prefixResolvedTags(
            query: tappedName,
            vocabulary: tagIndex.vocabulary,
            seedTag: tappedName
        )

        let excludeIDs = Set<UUID>([sourceItem.id]).union(exactMatchIDs)

        return await TagRelationService.expandAndRankAdjacent(
            semanticQuery: tappedName,
            tappedTagForRanking: tappedTag.name,
            sourceTagsLLMContext: .sourceItem(tags: sourceItem.tagNames),
            tagIndex: tagIndex,
            initialPrefixResolved: prefixResolved,
            excludeIDsFromMatchingSection: excludeIDs,
            allItemsForLookup: allItems,
            stage1Adjacent: stage1Adjacent
        )
    }
}
