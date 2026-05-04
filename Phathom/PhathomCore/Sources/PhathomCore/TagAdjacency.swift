import Foundation

/// Pure helpers for tag-set adjacency (library search + related items). Keeps scoring/remap logic out of UI-facing service types.
public enum TagAdjacency {
    /// Jaccard similarity for two tag-name sets. Returns `0` if disjoint or if intersection is empty.
    public static func jaccardScore(_ a: Set<String>, _ b: Set<String>) -> Double {
        let inter = a.intersection(b)
        guard !inter.isEmpty else { return 0 }
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(inter.count) / Double(union.count)
    }

    /// Map ranked IDs back to `ContentItem` in that order; IDs missing from `items` are dropped.
    public static func remapOrdered(ids: [UUID], from items: [ContentItem]) -> [ContentItem] {
        let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var ordered: [ContentItem] = []
        ordered.reserveCapacity(ids.count)
        for id in ids {
            if let item = lookup[id] { ordered.append(item) }
        }
        return ordered
    }
}
