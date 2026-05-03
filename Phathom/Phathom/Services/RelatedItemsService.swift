import PhathomCore
import Foundation

/// Tag-tap related-items pipeline.
///
/// Stage 1 (sync) buckets non-archived candidate items into:
///   - **Bucket A — exact matches**: items that contain the tapped tag (no cap)
///   - **Bucket B — adjacent**: items that do NOT contain the tapped tag but share ≥1 other tag
///     with the source item (sorted by Jaccard descending, capped at 8)
///
/// Stage 2 (async) re-ranks only Bucket B via `SharedLlamaInference`.
///
/// Final order = Bucket A (createdAt desc) + re-ranked Bucket B; sheet shows top 3.
enum RelatedItemsService {
    static let adjacentCandidateLimit = 8
    static let displayLimit = 3

    struct Buckets {
        let exactMatches: [ContentItem]
        let adjacentCandidates: [ContentItem]
    }

    /// Stage 1: partition candidates into disjoint buckets. `allItems` is the caller's already-loaded
    /// SwiftData query; we filter `isArchived` and `sourceItem.id` here so the caller doesn't have to.
    static func bucket(
        for sourceItem: ContentItem,
        tappedTag: Tag,
        in allItems: [ContentItem]
    ) -> Buckets {
        let tappedName = tappedTag.name.lowercased()
        let sourceTagNames = Set(sourceItem.tags.map { $0.name.lowercased() })

        var exact: [ContentItem] = []
        var adjacent: [(item: ContentItem, jaccard: Double)] = []

        for candidate in allItems {
            if candidate.isArchived { continue }
            if candidate.id == sourceItem.id { continue }
            let candidateNames = Set(candidate.tags.map { $0.name.lowercased() })
            if candidateNames.isEmpty { continue }
            if candidateNames.contains(tappedName) {
                exact.append(candidate)
            } else {
                let intersection = sourceTagNames.intersection(candidateNames)
                if intersection.isEmpty { continue }
                let union = sourceTagNames.union(candidateNames)
                guard !union.isEmpty else { continue }
                let score = Double(intersection.count) / Double(union.count)
                adjacent.append((candidate, score))
            }
        }

        let sortedExact = exact.sorted { $0.createdAt > $1.createdAt }
        let sortedAdjacent = adjacent
            .sorted { lhs, rhs in
                if lhs.jaccard != rhs.jaccard { return lhs.jaccard > rhs.jaccard }
                return lhs.item.createdAt > rhs.item.createdAt
            }
            .prefix(adjacentCandidateLimit)
            .map(\.item)

        return Buckets(exactMatches: sortedExact, adjacentCandidates: Array(sortedAdjacent))
    }

    /// Stage 2: re-rank Bucket B via Llama. On any failure (no model, parse error, cancellation),
    /// returns `adjacentCandidates` in the input order so the sheet still shows useful results.
    static func rerankAdjacent(
        tappedTag: Tag,
        sourceItem: ContentItem,
        adjacentCandidates: [ContentItem]
    ) async -> [ContentItem] {
        guard !adjacentCandidates.isEmpty else { return [] }
        let tappedName = tappedTag.name
        let sourceTagNames = sourceItem.tags.map(\.name)
        let payload: [(id: UUID, tagNames: [String])] = adjacentCandidates.map { item in
            (id: item.id, tagNames: item.tags.map(\.name))
        }

        do {
            let orderedIDs = try await SharedLlamaInference.shared.withSession(unloadOnExit: true, pipelineItemID: nil) { session in
                try await session.rankAdjacentItems(
                    tappedTag: tappedName,
                    sourceTagNames: sourceTagNames,
                    candidates: payload
                )
            }
            let lookup = Dictionary(uniqueKeysWithValues: adjacentCandidates.map { ($0.id, $0) })
            var ordered: [ContentItem] = []
            ordered.reserveCapacity(adjacentCandidates.count)
            for id in orderedIDs {
                if let match = lookup[id] { ordered.append(match) }
            }
            return ordered
        } catch {
            return adjacentCandidates
        }
    }

    /// Final sheet output: Bucket A (already in createdAt-desc order) followed by re-ranked Bucket B,
    /// truncated to `displayLimit` (3) items.
    static func combinedTopResults(
        exactMatches: [ContentItem],
        rerankedAdjacent: [ContentItem]
    ) -> [ContentItem] {
        var combined: [ContentItem] = []
        combined.reserveCapacity(displayLimit)
        var seen = Set<UUID>()
        for item in exactMatches + rerankedAdjacent {
            if seen.contains(item.id) { continue }
            combined.append(item)
            seen.insert(item.id)
            if combined.count >= displayLimit { break }
        }
        return combined
    }
}
