import Foundation

/// Deterministic normalization for tag names from LLM output and platform hashtags.
public enum TagNameNormalizer {
    /// Returns `nil` if the string is empty or does not meet length constraints after cleanup.
    public static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") {
            s = String(s.dropFirst())
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !s.isEmpty else { return nil }

        s = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        s = s.lowercased()

        var builder = ""
        builder.reserveCapacity(s.unicodeScalars.count)
        for scalar in s.unicodeScalars {
            let ch = Character(scalar)
            if ("a" ... "z").contains(ch) || ("0" ... "9").contains(ch) || ch == "-" {
                builder.append(ch)
            } else {
                builder.append("-")
            }
        }

        var collapsed = ""
        collapsed.reserveCapacity(builder.count)
        var previousWasHyphen = false
        for ch in builder {
            if ch == "-" {
                guard !previousWasHyphen else { continue }
                previousWasHyphen = true
                collapsed.append(ch)
            } else {
                previousWasHyphen = false
                collapsed.append(ch)
            }
        }
        collapsed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        guard collapsed.count >= 2, collapsed.count <= 40 else { return nil }
        return collapsed
    }

    /// Order-preserving deduplication after per-string normalization.
    public static func normalize(many raws: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        out.reserveCapacity(raws.count)
        for raw in raws {
            guard let n = normalize(raw) else { continue }
            if seen.insert(n).inserted {
                out.append(n)
            }
        }
        return out
    }
}
