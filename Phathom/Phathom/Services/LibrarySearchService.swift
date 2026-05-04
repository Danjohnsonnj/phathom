import PhathomCore
import Foundation

/// Library search bucketing — mirrors the Stage 1 contract of `RelatedItemsService`, but driven by the
/// Library search box instead of a tapped tag.
///
/// **Stage 1 (sync, fast)**:
///   - `matching`: substring filter across title, raw text, host, URL, media description, and tags
///     (preserves the previous `LibraryTab.filteredItems` behavior so we don't regress discovery).
///   - `adjacent`: only when the trimmed query equals a known tag name (case-insensitive). Returns
///     items that do NOT contain the resolved tag but share at least one tag with any **anchor** item:
///     either a substring-matching item, or — when matching is empty — any item that carries the
///     resolved tag (library filter still applies). Ranked by max Jaccard vs anchors, capped at 8.
///
/// **Stage 2 (async, "Dive deeper")** lives in `LibraryTab` and calls `diveDeeper(...)` below,
/// which: (1) collects prefix-matching tags synchronously, (2) runs `expandTagsSemantically` via
/// Llama to widen the resolved tag set, (3) expands the adjacent candidate pool via `ItemSnapshot`,
/// and (4) re-ranks with `rankAdjacentItems` — all inside one `withSession` to avoid redundant
/// load/unload cycles. On any failure the Stage 1 adjacent order is preserved.
enum LibrarySearchService {
    static let adjacentCandidateLimit = RelatedItemsService.adjacentCandidateLimit

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
    /// kind filtering happens here so adjacency respects the active filter pill.
    static func bucket(
        query: String,
        items: [ContentItem],
        filterKind: ContentKind?
    ) -> Sections {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (kindFiltered, tagIndex) = buildTagIndex(items: items, filterKind: filterKind)
        guard !normalized.isEmpty else {
            return Sections(matching: kindFiltered, adjacent: [], resolvedTagName: nil)
        }
        // Inverted index `tagIndex` is keyed by lowercased tag name. `Tag.init` already lowercases
        // names on insert, so a direct subscript with `normalized` resolves the tag without re-
        // normalizing.

        let matching = kindFiltered.filter { item in
            let titleMatch = item.displayTitle.lowercased().contains(normalized)
            let rawTextMatch = (item.rawText ?? "").lowercased().contains(normalized)
            let hostMatch = (item.displayHost ?? "").lowercased().contains(normalized)
            let urlMatch = (item.originalURL?.absoluteString ?? "").lowercased().contains(normalized)
            let mediaMatch = (item.mediaDescription ?? "").lowercased().contains(normalized)
            let tagsMatch = item.tagNames.joined(separator: " ").lowercased().contains(normalized)
            return titleMatch || rawTextMatch || hostMatch || urlMatch || mediaMatch || tagsMatch
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
                adjacent = computeAdjacent(
                    resolvedTags: [resolvedTag],
                    anchorItems: anchorItems,
                    excludeIDs: [],
                    tagIndex: tagIndex
                )
            }
        } else {
            adjacent = []
        }

        return Sections(matching: matching, adjacent: adjacent, resolvedTagName: resolvedTagName)
    }

    /// Use the inverted index to expand from anchor items to candidates that share at least one
    /// non-resolved tag, then score by max Jaccard against any anchor. Bounded by the index rather
    /// than the whole library, so a broad query doesn't fan out to O(n × m) work.
    ///
    /// `resolvedTags` is the set of tag names whose carriers are excluded from adjacency. For Stage 1
    /// this is just the single resolved tag; for "Dive deeper" this can include the prefix-matched
    /// and Llama-expanded tags as well.
    /// `excludeIDs` is an additional ID-level exclusion (e.g. items already shown in the Matching
    /// section) — anchors are excluded automatically.
    static func computeAdjacent(
        resolvedTags: Set<String>,
        anchorItems: [ContentItem],
        excludeIDs: Set<UUID>,
        tagIndex: [String: [ContentItem]]
    ) -> [ContentItem] {
        let anchorIDs = Set(anchorItems.map(\.id))
        let seedTagSets: [Set<String>] = anchorItems.map { Set($0.tagNames) }

        var candidatesByID: [UUID: ContentItem] = [:]
        for seedTags in seedTagSets {
            for seedTag in seedTags where !resolvedTags.contains(seedTag) {
                guard let bucket = tagIndex[seedTag] else { continue }
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
            // Defensive: adjacent never includes items that carry any resolved tag.
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

    /// Build the same kind-filtered tag inverted index used inside `bucket`. Exposed so that the
    /// `diveDeeper` flow can reuse it without re-running Stage 1 substring matching.
    static func buildTagIndex(
        items: [ContentItem],
        filterKind: ContentKind?
    ) -> (kindFiltered: [ContentItem], tagIndex: [String: [ContentItem]]) {
        let kindFiltered: [ContentItem]
        if let filterKind {
            kindFiltered = items.filter { $0.kind == filterKind }
        } else {
            kindFiltered = items
        }
        var tagIndex: [String: [ContentItem]] = [:]
        for item in kindFiltered {
            for tag in item.tags {
                tagIndex[tag.name, default: []].append(item)
            }
        }
        return (kindFiltered, tagIndex)
    }

    /// "Dive deeper": semantic + prefix tag expansion via Llama, then `computeAdjacent` over the
    /// union of resolved tags, then `rankAdjacentItems` over the expanded set. Two Llama calls
    /// happen inside one `withSession` so the model is loaded once.
    ///
    /// On any error (no model, parse error, cancellation), returns the original `sections.adjacent`
    /// so the UI keeps its Stage 1 ranking — same fallback contract as `RelatedItemsService.rerankAdjacent`.
    static func diveDeeper(
        query: String,
        sections: Sections,
        allItems: [ContentItem],
        filterKind: ContentKind?
    ) async -> [ContentItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return sections.adjacent }

        let (_, tagIndex) = buildTagIndex(items: allItems, filterKind: filterKind)
        let vocabulary = Array(tagIndex.keys)
        guard !vocabulary.isEmpty else { return sections.adjacent }

        // Sync prefix expansion: free, deterministic, runs even if the Llama call fails.
        var prefixResolved: Set<String> = []
        if let exact = sections.resolvedTagName {
            prefixResolved.insert(exact)
        }
        for tagName in vocabulary {
            if tagName.hasPrefix(normalized) || tagName.contains("-\(normalized)") {
                prefixResolved.insert(tagName)
            }
        }

        // The session closure captures only Sendable / value-typed state — no `ContentItem` —
        // because `ContentItem` is a `@Model` and not Sendable. We rebuild the model lookups
        // outside the session once we have the ranked UUIDs.
        let resolvedAtEntry = prefixResolved
        let queryForSession = normalized
        let exactTag = sections.resolvedTagName
        let matchingIDs = Set(sections.matching.map(\.id))

        let snapshot = ItemSnapshot(items: allItems, filterKind: filterKind)

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
                    print("[LibrarySearchService] expandTagsSemantically failed, continuing with prefix-only expansion: \(error)")
                    #endif
                    semantic = []
                }

                var resolvedTags = resolvedAtEntry
                resolvedTags.formUnion(semantic)
                if resolvedTags.isEmpty { return [] }

                let expanded = snapshot.expandedAdjacent(
                    resolvedTags: resolvedTags,
                    excludeIDs: matchingIDs,
                    limit: adjacentCandidateLimit
                )
                if expanded.isEmpty { return [] }

                let payload: [(id: UUID, tagNames: [String])] = expanded.map { id in
                    (id: id, tagNames: snapshot.tagsByID[id] ?? [])
                }
                return try await session.rankAdjacentItems(
                    tappedTag: exactTag ?? queryForSession,
                    sourceTagNames: Array(resolvedTags),
                    candidates: payload
                )
            }
        } catch {
            return sections.adjacent
        }

        if rankedIDs.isEmpty { return sections.adjacent }
        let ordered = TagAdjacency.remapOrdered(ids: rankedIDs, from: allItems)
        return ordered.isEmpty ? sections.adjacent : ordered
    }

    /// Value-typed snapshot of the kind-filtered items so the Llama session closure does not
    /// capture `ContentItem` (which is a `@Model` and therefore not Sendable). All work that
    /// previously needed `ContentItem` instances is reformulated on UUID + tag-name lookups.
    private struct ItemSnapshot: Sendable {
        let tagsByID: [UUID: [String]]
        let createdAtByID: [UUID: Date]
        let tagIndex: [String: [UUID]]
        let vocabulary: [String]

        init(items: [ContentItem], filterKind: ContentKind?) {
            let kindFiltered: [ContentItem]
            if let filterKind {
                kindFiltered = items.filter { $0.kind == filterKind }
            } else {
                kindFiltered = items
            }
            var tagsByID: [UUID: [String]] = [:]
            var createdAtByID: [UUID: Date] = [:]
            var tagIndex: [String: [UUID]] = [:]
            for item in kindFiltered {
                let names = item.tagNames
                tagsByID[item.id] = names
                createdAtByID[item.id] = item.createdAt
                for name in names {
                    tagIndex[name, default: []].append(item.id)
                }
            }
            self.tagsByID = tagsByID
            self.createdAtByID = createdAtByID
            self.tagIndex = tagIndex
            self.vocabulary = Array(tagIndex.keys)
        }

        /// Mirror of `computeAdjacent` operating only on UUIDs / tag names so it can run inside the
        /// `@Sendable` session closure without capturing `ContentItem`. Returns ordered IDs (top
        /// `limit`) by max Jaccard, with `createdAt` tie-break.
        func expandedAdjacent(
            resolvedTags: Set<String>,
            excludeIDs: Set<UUID>,
            limit: Int
        ) -> [UUID] {
            var anchorIDs: Set<UUID> = []
            for tag in resolvedTags {
                if let ids = tagIndex[tag] { anchorIDs.formUnion(ids) }
            }
            if anchorIDs.isEmpty { return [] }
            let seedTagSets: [Set<String>] = anchorIDs.compactMap { tagsByID[$0].map(Set.init) }

            var candidateIDs: Set<UUID> = []
            for seedTags in seedTagSets {
                for seedTag in seedTags where !resolvedTags.contains(seedTag) {
                    guard let ids = tagIndex[seedTag] else { continue }
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
