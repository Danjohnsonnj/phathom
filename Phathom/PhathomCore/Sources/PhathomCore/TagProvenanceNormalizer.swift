import Foundation

/// Normalizes and mutates `userAddedTagNames` at Detail TagEditSheet write boundaries.
public enum TagProvenanceNormalizer {
    /// Map through `TagNameNormalizer`, drop nil, dedupe preserving order.
    public static func normalizeMany(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        out.reserveCapacity(raw.count)
        for rawName in raw {
            guard let normalized = TagNameNormalizer.normalize(rawName) else { continue }
            if seen.insert(normalized).inserted {
                out.append(normalized)
            }
        }
        return out
    }

    public static func applyAdd(current: [String], added: String) -> [String] {
        guard let normalized = TagNameNormalizer.normalize(added) else { return normalizeMany(current) }
        var out = normalizeMany(current)
        if !out.contains(normalized) {
            out.append(normalized)
        }
        return out
    }

    public static func applyRename(current: [String], from oldName: String, to newName: String) -> [String] {
        let normalizedOld = TagNameNormalizer.normalize(oldName) ?? oldName
        guard let normalizedNew = TagNameNormalizer.normalize(newName) else {
            return applyDelete(current: current, removed: normalizedOld)
        }
        var out = normalizeMany(current)
        if let index = out.firstIndex(of: normalizedOld) {
            out.remove(at: index)
        }
        if !out.contains(normalizedNew) {
            out.append(normalizedNew)
        }
        return normalizeMany(out)
    }

    public static func applyDelete(current: [String], removed: String) -> [String] {
        let normalizedRemoved = TagNameNormalizer.normalize(removed) ?? removed
        return normalizeMany(current.filter { $0 != normalizedRemoved })
    }
}
