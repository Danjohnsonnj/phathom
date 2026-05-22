import PhathomCore
import Foundation

/// Shared tag inversion, prefix expansion, adjacent discovery, and LLM-assisted ranking used by library search
/// and detail tag-tap related items.
enum TagRelationService {
    /// Cap for adjacent candidates before Llama rerank (`rankAdjacentItems` assumes this upstream bound).
    static let adjacentCandidateLimit = 8

    /// How `rankAdjacentItems` consumes "source tags" context after semantic widening.
    enum LLMSourceTagsContext {
        /// Library Dive deeper: contextual tags are the merged expanded set (`prefix ∪ semantic`).
        case alignedWithExpandedResolvedTags
        /// Detail tag tap: keep source row’s tags for Llama tie-break (product contract).
        case sourceItem(tags: [String])
    }

    struct TagIndex {
        /// Items after kind/status/category filters (`buildTagIndex` pool).
        let filteredItems: [ContentItem]
        /// Lowercased tag name → items carrying that tag.
        let inverted: [String: [ContentItem]]

        init(filteredItems: [ContentItem], inverted: [String: [ContentItem]]) {
            self.filteredItems = filteredItems
            self.inverted = inverted
        }

        var vocabulary: [String] { Array(inverted.keys) }
    }

    // MARK: - Pool filtering

    static func itemsFilteredByKindStatusAndCategory(
        items: [ContentItem],
        filterKind: ContentKind?,
        filterStatus: ReadStatus?,
        filterCategory: String?
    ) -> [ContentItem] {
        var pool = items
        if let filterKind {
            pool = pool.filter { $0.kind == filterKind }
        }
        if let filterStatus {
            pool = pool.filter { $0.readState == filterStatus }
        }
        if let filterCategory {
            if filterCategory == LibraryCategoryFilterStorage.uncategorizedRaw {
                pool = pool.filter { $0.category == nil }
            } else {
                pool = pool.filter { $0.category?.name == filterCategory }
            }
        }
        return pool
    }

    /// Build inverted index over the filtered library pool (kind / status / category).
    static func buildTagIndex(
        items: [ContentItem],
        filterKind: ContentKind?,
        filterStatus: ReadStatus? = nil,
        filterCategory: String? = nil
    ) -> TagIndex {
        let filtered = itemsFilteredByKindStatusAndCategory(
            items: items,
            filterKind: filterKind,
            filterStatus: filterStatus,
            filterCategory: filterCategory
        )
        var inverted: [String: [ContentItem]] = [:]
        for item in filtered {
            for tag in item.tags {
                inverted[tag.name, default: []].append(item)
            }
        }
        return TagIndex(filteredItems: filtered, inverted: inverted)
    }

    // MARK: - Detail / dive-deeper prefix expansion

    /// Deterministic vocabulary prefix match (`LibrarySearchService` / dive-deeper contract).
    static func prefixResolvedTags(
        query: String,
        vocabulary: [String],
        seedTag: String?
    ) -> Set<String> {
        var prefixResolved = Set<String>()
        if let seedTag {
            prefixResolved.insert(seedTag)
        }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return prefixResolved }
        for tagName in vocabulary {
            if tagName.hasPrefix(normalized) || tagName.contains("-\(normalized)") {
                prefixResolved.insert(tagName)
            }
        }
        return prefixResolved
    }

    /// Other items carrying `tappedTagName` — excludes `excludingID`; non-archived only.
    static func exactMatchesOtherThanSource(
        tappedTagName: String,
        in allItems: [ContentItem],
        excludingSourceID: UUID
    ) -> [ContentItem] {
        let tapped = tappedTagName.lowercased()
        let exact = allItems.filter {
            !$0.isArchived &&
                $0.id != excludingSourceID &&
                Set($0.tagNames.map { $0.lowercased() }).contains(tapped)
        }
        return exact.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Adjacency (anchor-based)

    /// Expands `anchorItems` through the inverted index, scores by max Jaccard vs any anchor seed tag row.
    ///
    /// - `resolvedTags`: tags whose carriers cannot appear as adjacent candidates.
    /// - `excludeIDs`: extra exclusions (matching rows or exact-hit rows).
    /// - Anchors exclude themselves implicitly via `anchorIDs`.
    static func computeAdjacent(
        resolvedTags: Set<String>,
        anchorItems: [ContentItem],
        excludeIDs: Set<UUID>,
        inverted: [String: [ContentItem]]
    ) -> [ContentItem] {
        let anchorIDs = Set(anchorItems.map(\.id))
        let seedTagSets: [Set<String>] = anchorItems.map { Set($0.tagNames) }

        var candidatesByID: [UUID: ContentItem] = [:]
        for seedTags in seedTagSets {
            for seedTag in seedTags where !resolvedTags.contains(seedTag) {
                guard let bucket = inverted[seedTag] else { continue }
                for item in bucket {
                    if anchorIDs.contains(item.id) { continue }
                    if excludeIDs.contains(item.id) { continue }
                    candidatesByID[item.id] = item
                }
            }
        }

        var scored: [(item: ContentItem, jaccard: Double)] = []
        scored.reserveCapacity(candidatesByID.count)
        for (_, candidate) in candidatesByID {
            let candidateTags = Set(candidate.tagNames)
            if candidateTags.isEmpty { continue }
            if !candidateTags.intersection(resolvedTags).isEmpty { continue }

            var bestScore: Double = 0
            for seedTags in seedTagSets {
                let score = TagAdjacency.jaccardScore(candidateTags, seedTags)
                if score > bestScore { bestScore = score }
            }
            if bestScore > 0 {
                scored.append((candidate, bestScore))
            }
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.jaccard != rhs.jaccard { return lhs.jaccard > rhs.jaccard }
                return lhs.item.createdAt > rhs.item.createdAt
            }
            .prefix(adjacentCandidateLimit)
            .map(\.item)
    }

    /// Dive-deeper / detail anchors: union of carriers of each resolved tag name.
    static func computeAdjacentFromResolvedTags(
        resolvedTags: Set<String>,
        inverted: [String: [ContentItem]],
        excludeIDs: Set<UUID>
    ) -> [ContentItem] {
        guard !resolvedTags.isEmpty else { return [] }
        var anchorByID = [UUID: ContentItem]()
        for tag in resolvedTags {
            guard let carriers = inverted[tag] else { continue }
            for item in carriers {
                anchorByID[item.id] = item
            }
        }
        let anchors = Array(anchorByID.values)
        guard !anchors.isEmpty else { return [] }
        return computeAdjacent(
            resolvedTags: resolvedTags,
            anchorItems: anchors,
            excludeIDs: excludeIDs,
            inverted: inverted
        )
    }

    // MARK: - LLM: semantic expansion + rerank

    /// Prefix + semantic widening, expanded adjacent pool selection, Llama rerank — one session.
    /// - `semanticQuery`: trimmed lowercased string for `expandTagsSemantically` (typically normalized search query).
    /// - `tappedTagForRanking` / `sourceTagsForRanking`: forwarded to `rankAdjacentItems`.
    ///
    /// On failure returns `stage1Adjacent` unchanged.
    static func expandAndRankAdjacent(
        semanticQuery: String,
        tappedTagForRanking: String,
        sourceTagsLLMContext: LLMSourceTagsContext,
        tagIndex: TagIndex,
        initialPrefixResolved: Set<String>,
        excludeIDsFromMatchingSection: Set<UUID>,
        allItemsForLookup: [ContentItem],
        stage1Adjacent: [ContentItem]
    ) async -> [ContentItem] {
        let trimmed = semanticQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return stage1Adjacent }

        let vocabulary = tagIndex.vocabulary
        guard !vocabulary.isEmpty else { return stage1Adjacent }

        let resolvedAtEntry = initialPrefixResolved
        let queryForSession = trimmed
        let tappedForRanking = tappedTagForRanking
        let excludeIDs = excludeIDsFromMatchingSection
        let sourceTagsStrategy = sourceTagsLLMContext

        let snapshot = AdjacencyItemSnapshot(kindFilteredItems: tagIndex.filteredItems)

        let rankedIDs: [UUID]
        do {
            rankedIDs = try await SharedLlamaInference.shared.withSession(
                unloadOnExit: true,
                pipelineItemID: nil
            ) { session in
                let semantic: [String]
                do {
                    semantic = try await session.expandTagsSemantically(
                        query: queryForSession,
                        libraryTagNames: snapshot.vocabulary
                    )
                } catch {
                    #if DEBUG
                    print("[TagRelationService] expandTagsSemantically failed, continuing with prefix-only expansion: \(error)")
                    #endif
                    semantic = []
                }

                var resolvedTags = resolvedAtEntry
                resolvedTags.formUnion(semantic)
                if resolvedTags.isEmpty { return [] }

                let expanded = snapshot.expandedAdjacent(
                    resolvedTags: resolvedTags,
                    excludeIDs: excludeIDs,
                    limit: adjacentCandidateLimit
                )
                if expanded.isEmpty { return [] }

                let sourceForRanking: [String]
                switch sourceTagsStrategy {
                case .alignedWithExpandedResolvedTags:
                    sourceForRanking = Array(resolvedTags)
                case .sourceItem(let tags):
                    sourceForRanking = tags
                }

                let payload: [(id: UUID, tagNames: [String])] = expanded.map { id in
                    (id: id, tagNames: snapshot.tagsByID[id] ?? [])
                }
                return try await session.rankAdjacentItems(
                    tappedTag: tappedForRanking,
                    sourceTagNames: sourceForRanking,
                    candidates: payload
                )
            }
        } catch {
            return stage1Adjacent
        }

        if rankedIDs.isEmpty { return stage1Adjacent }
        let ordered = TagAdjacency.remapOrdered(ids: rankedIDs, from: allItemsForLookup)
        return ordered.isEmpty ? stage1Adjacent : ordered
    }

    /// Value-typed snapshot for Sendable Llama closures (no `@Model`).
    struct AdjacencyItemSnapshot: Sendable {
        let tagsByID: [UUID: [String]]
        let createdAtByID: [UUID: Date]
        let tagIndexUUID: [String: [UUID]]
        let vocabulary: [String]

        init(kindFilteredItems: [ContentItem]) {
            var tagsByID: [UUID: [String]] = [:]
            var createdAtByID: [UUID: Date] = [:]
            var tagIndexUUID: [String: [UUID]] = [:]
            for item in kindFilteredItems {
                let names = item.tagNames
                tagsByID[item.id] = names
                createdAtByID[item.id] = item.createdAt
                for name in names {
                    tagIndexUUID[name, default: []].append(item.id)
                }
            }
            self.tagsByID = tagsByID
            self.createdAtByID = createdAtByID
            self.tagIndexUUID = tagIndexUUID
            self.vocabulary = Array(tagIndexUUID.keys)
        }

        /// Top `limit` candidate IDs adjacent to carriers of `resolvedTags`, max Jaccard vs anchor tag sets.
        func expandedAdjacent(
            resolvedTags: Set<String>,
            excludeIDs: Set<UUID>,
            limit: Int
        ) -> [UUID] {
            var anchorIDs: Set<UUID> = []
            for tag in resolvedTags {
                if let ids = tagIndexUUID[tag] { anchorIDs.formUnion(ids) }
            }
            if anchorIDs.isEmpty { return [] }
            let seedTagSets: [Set<String>] = anchorIDs.compactMap { tagsByID[$0].map(Set.init) }

            var candidateIDs: Set<UUID> = []
            for seedTags in seedTagSets {
                for seedTag in seedTags where !resolvedTags.contains(seedTag) {
                    guard let ids = tagIndexUUID[seedTag] else { continue }
                    for id in ids {
                        if anchorIDs.contains(id) { continue }
                        if excludeIDs.contains(id) { continue }
                        candidateIDs.insert(id)
                    }
                }
            }

            var scored: [(id: UUID, jaccard: Double, createdAt: Date)] = []
            scored.reserveCapacity(candidateIDs.count)
            for id in candidateIDs {
                guard let names = tagsByID[id] else { continue }
                let candidateTags = Set(names)
                if candidateTags.isEmpty { continue }
                if !candidateTags.intersection(resolvedTags).isEmpty { continue }
                var bestScore: Double = 0
                for seedTags in seedTagSets {
                    let score = TagAdjacency.jaccardScore(candidateTags, seedTags)
                    if score > bestScore { bestScore = score }
                }
                if bestScore > 0 {
                    scored.append((id, bestScore, createdAtByID[id] ?? .distantPast))
                }
            }

            return scored
                .sorted { lhs, rhs in
                    if lhs.jaccard != rhs.jaccard { return lhs.jaccard > rhs.jaccard }
                    return lhs.createdAt > rhs.createdAt
                }
                .prefix(limit)
                .map(\.id)
        }
    }
}
