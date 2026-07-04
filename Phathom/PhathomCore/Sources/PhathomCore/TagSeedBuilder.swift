import Foundation

/// Pure, store-free selector for the dynamic subject-tag seed injected into the tagging prompt.
///
/// The seed is the user's own frequently-reused subject tags. Tags used fewer than `floor` times are
/// excluded (this drops the long tail of one-off singletons that drive proliferation); the remainder is
/// ordered by descending usage and capped at `cap`.
public enum TagSeedBuilder {
    /// Default minimum item count for a tag to qualify for the seed.
    public static let defaultFloor = 3
    /// Default maximum number of seed tags injected into the prompt.
    public static let defaultCap = 15
    /// Minimum cross-item provenance count to promote a name into the content-type list.
    public static let defaultProvenancePromotionFloor = 2
    /// Maximum promoted content-type names beyond the base enum.
    public static let defaultPromotedContentTypeCap = 5

    /// Subject seed: user-added provenance names first (lex ascending), then frequency candidates.
    public static func selectSubjectSeed(
        userAdded: [String],
        frequencyCandidates: [(name: String, count: Int)],
        floor: Int = defaultFloor,
        cap: Int = defaultCap
    ) -> [String] {
        guard cap > 0 else { return [] }

        var result: [String] = []
        var seen = Set<String>()

        for name in userAdded.sorted() {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
            if result.count >= cap { return result }
        }

        let remainingCap = cap - result.count
        guard remainingCap > 0 else { return result }

        let filteredFrequency = frequencyCandidates.filter { candidate in
            let trimmed = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !seen.contains(trimmed)
        }
        let frequencySeed = select(from: filteredFrequency, floor: floor, cap: remainingCap)
        result.append(contentsOf: frequencySeed)
        return result
    }

    /// Promotes provenance names into the content-type list when used on enough active items.
    public static func selectPromotedContentTypes(
        provenanceCounts: [(name: String, count: Int)],
        baseVocabulary: [String],
        promotionFloor: Int = defaultProvenancePromotionFloor,
        cap: Int = defaultPromotedContentTypeCap
    ) -> [String] {
        guard cap > 0 else { return [] }

        let baseSet = Set(baseVocabulary)
        let qualifying = provenanceCounts.compactMap { candidate -> (name: String, count: Int)? in
            let trimmed = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !baseSet.contains(trimmed),
                  candidate.count >= promotionFloor
            else { return nil }
            return (name: trimmed, count: candidate.count)
        }

        let sorted = qualifying.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
            return lhs.name < rhs.name
        }

        return Array(sorted.prefix(cap).map(\.name))
    }

    /// Selects seed tag names from `(name, count)` pairs.
    ///
    /// - Parameters:
    ///   - candidates: tag name + number of items carrying it.
    ///   - floor: tags with `count < floor` are excluded.
    ///   - cap: maximum number of names returned.
    /// - Returns: qualifying names sorted by count (desc), then shorter name, then lexicographically;
    ///   deterministic for stable input.
    public static func select(
        from candidates: [(name: String, count: Int)],
        floor: Int = defaultFloor,
        cap: Int = defaultCap
    ) -> [String] {
        guard cap > 0 else { return [] }

        let qualifying = candidates.compactMap { candidate -> (name: String, count: Int)? in
            let trimmed = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, candidate.count >= floor else { return nil }
            return (name: trimmed, count: candidate.count)
        }

        let sorted = qualifying.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
            return lhs.name < rhs.name
        }

        return Array(sorted.prefix(cap).map(\.name))
    }
}
