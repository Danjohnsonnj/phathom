import Foundation

// MARK: - Open Graph caption normalization

public enum InstagramSocialCaption {
    /// Primary: `og:description` with Meta’s stats + quote wrapper stripped. Falls back to `og:title` framing removal.
    public static func normalizedCaption(ogDescription: String?, ogTitle: String?) -> String {
        if let d = ogDescription, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let stripped = InstagramSocialCaption.stripStatsAndQuotesPrefix(d)
            if !stripped.isEmpty {
                return InstagramSocialCaption.decodeBasicHTMLEntities(stripped)
            }
        }
        if let t = ogTitle, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let stripped = InstagramSocialCaption.stripInstagramTitleFraming(t)
            if !stripped.isEmpty {
                return InstagramSocialCaption.decodeBasicHTMLEntities(stripped)
            }
        }
        return ""
    }

    /// Caption string to feed [`SocialListTitle`](SocialListTitle); may drop a leading reel audio attribution line.
    public static func captionForListTitle(normalizedCaption: String) -> String {
        let lines = normalizedCaption.components(separatedBy: "\n")
        var nonEmptyIndices: [Int] = []
        for (idx, line) in lines.enumerated() {
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nonEmptyIndices.append(idx)
            }
        }
        guard nonEmptyIndices.count >= 2 else { return normalizedCaption }
        let i0 = nonEmptyIndices[0]
        let i1 = nonEmptyIndices[1]
        let first = lines[i0].trimmingCharacters(in: .whitespacesAndNewlines)
        let second = lines[i1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard second.count >= 12 else { return normalizedCaption }
        guard InstagramSocialCaption.isLikelyAudioAttributionLine(first) else { return normalizedCaption }
        let rest = Array(lines[(i0 + 1)...])
        return rest.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func suggestedListTitle(fromNormalizedCaption caption: String) -> String? {
        SocialListTitle.fromCaption(captionForListTitle(normalizedCaption: caption))
    }

    // "1,581 likes, 9 comments - handle on April 26, 2026: \"…"
    private static func stripStatsAndQuotesPrefix(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^[\d,]+\s+(?:likes?|views?),\s*[\d,]+\s+comments?\s*-\s*.+?\s+on\s+[^:]+:\s*"#,
            #"^[\d,]+\s+(?:likes?|views?),\s*[\d,]+\s+comments?\s*-\s*[^:]+:\s*"#,
        ]
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        guard let matchedRange = firstMatchRange(in: trimmed, patterns: patterns, range: range),
              let r = Range(matchedRange, in: trimmed) else {
            return trimmed
        }
        var body = String(trimmed[r.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        body = trimWrappingQuotes(in: body)
        if body.hasSuffix(".") && !body.hasSuffix("…") {
            body = String(body.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return body
    }

    private static func stripInstagramTitleFraming(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\s+on\s+Instagram:\s*\""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return trimmed
        }
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              let r = Range(match.range, in: trimmed) else {
            return trimmed
        }
        let body = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimWrappingQuotes(in: body)
    }

    private static func isLikelyAudioAttributionLine(_ line: String) -> Bool {
        if line.count > 120 { return false }
        if line.contains("·") || line.contains("•") { return true }
        if line.range(of: #"(?i)\b(original\s+sound|original\s+audio)\b"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func decodeBasicHTMLEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func firstMatchRange(in string: String, patterns: [String], range: NSRange) -> NSRange? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            if let match = regex.firstMatch(in: string, options: [], range: range) {
                return match.range
            }
        }
        return nil
    }

    private static func trimWrappingQuotes(in text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("\"") {
            body = String(body.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if body.hasSuffix("\".") {
            body = String(body.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if body.hasSuffix("\"") {
            body = String(body.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return body
    }
}
