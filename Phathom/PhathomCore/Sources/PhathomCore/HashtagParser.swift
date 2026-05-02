import Foundation

public enum HashtagParser {
    /// Parses `#tags` from text; returns lowercase names without `#`, first-seen order, unique.
    public static func tagNames(in text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] != "#" {
                i = text.index(after: i)
                continue
            }
            var j = text.index(after: i)
            let tokenStart = j
            while j < text.endIndex, isHashtagContinuation(text[j]) {
                j = text.index(after: j)
            }
            if j > tokenStart {
                let raw = String(text[tokenStart ..< j])
                let name = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !seen.contains(name) {
                    seen.insert(name)
                    result.append(name)
                }
            }
            i = j
        }
        return result
    }

    private static func isHashtagContinuation(_ ch: Character) -> Bool {
        if ch == "_" { return true }
        if ch.isLetter || ch.isNumber { return true }
        if ch == "\u{00B7}" || ch == "\u{30FB}" { return true }
        return false
    }
}
