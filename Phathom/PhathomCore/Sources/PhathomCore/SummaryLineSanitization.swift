import Foundation

/// Normalizes LLM-produced summary lines for safe single-line display (detail, library, Spotlight).
public enum SummaryLineSanitization {
    public static func sanitizedBullet(_ raw: String) -> String {
        var kept = String.UnicodeScalarView()
        kept.reserveCapacity(raw.unicodeScalars.count)
        for s in raw.unicodeScalars where !strippedCodePoints.contains(s.value) {
            kept.append(s)
        }
        let string = String(kept)
        let pieces = string.split(whereSeparator: \.isWhitespace)
        return pieces.joined(separator: " ")
    }

    public static func sanitizedBullets(_ bullets: [String]) -> [String] {
        bullets.map { sanitizedBullet($0) }.filter { !$0.isEmpty }
    }

    /// Returns source preview with normalized whitespace, capped to first `maxWords`.
    public static func sourcePreview(_ raw: String, maxWords: Int = 50) -> String? {
        guard maxWords > 0 else { return nil }
        let cleaned = sanitizedBullet(MarkdownNoteHelpers.plainSnippet(from: raw))
        guard !cleaned.isEmpty else { return nil }
        let words = cleaned.split(separator: " ")
        guard !words.isEmpty else { return nil }
        let truncated = words.count > maxWords
        let base = truncated ? words.prefix(maxWords).joined(separator: " ") : cleaned
        return truncated ? "\(base)..." : base
    }

    /// Returns markdown-preserving source preview, capped to first `maxWords`.
    public static func sourceMarkdownPreview(_ raw: String, maxWords: Int = 50) -> String? {
        guard maxWords > 0 else { return nil }
        let strippedControls = String(String.UnicodeScalarView(raw.unicodeScalars.filter {
            !strippedCodePoints.contains($0.value)
        }))
        let normalizedHeadings = normalizeHeadingLevels(in: strippedControls)
        let normalized = normalizedHeadings
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let words = normalized.split(separator: " ")
        guard !words.isEmpty else { return nil }
        let truncated = words.count > maxWords
        let capped = words.prefix(maxWords).joined(separator: " ")
        let repaired = repairDanglingMarkdownTail(capped)
        let final = repaired.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else { return nil }
        return truncated ? "\(final)..." : final
    }

    private static func repairDanglingMarkdownTail(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return text }

        func needsTrim(_ s: String) -> Bool {
            if s.filter({ $0 == "[" }).count > s.filter({ $0 == "]" }).count { return true }
            if s.filter({ $0 == "(" }).count > s.filter({ $0 == ")" }).count { return true }
            let doubleAsteriskCount = s.components(separatedBy: "**").count - 1
            if doubleAsteriskCount % 2 != 0 { return true }
            let singleAsteriskCount = s.filter({ $0 == "*" }).count - (doubleAsteriskCount * 2)
            if singleAsteriskCount % 2 != 0 { return true }
            return false
        }

        while !words.isEmpty {
            let candidate = words.joined(separator: " ")
            if !needsTrim(candidate) {
                return candidate
            }
            _ = words.popLast()
        }

        return text
    }

    private static func normalizeHeadingLevels(in raw: String) -> String {
        raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let s = String(line)
                guard let range = s.range(of: #"^\s{0,3}#{1,6}\s+"#, options: .regularExpression) else {
                    return s
                }
                let content = s[range.upperBound...]
                return "#### " + content
            }
            .joined(separator: "\n")
    }

    private static let strippedCodePoints: Set<UInt32> = [
        0xFEFF, // BOM
        0x200E, 0x200F, // LRM / RLM
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // explicit embedding / override / PDF
        0x2066, 0x2067, 0x2068, 0x2069, // isolate controls
    ]
}
