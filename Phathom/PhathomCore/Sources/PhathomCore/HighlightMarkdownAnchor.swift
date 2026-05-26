import Foundation

/// Resolves UTF-16 highlight anchors in stored `sourceMarkdown` from WKWebView selection payloads.
public enum HighlightMarkdownAnchor {
    public struct Resolved: Sendable, Equatable {
        public let offset: Int
        public let length: Int

        public init(offset: Int, length: Int) {
            self.offset = offset
            self.length = length
        }
    }

    /// Verifies `quotedText` against `markdown[offset..<offset+length]`; on mismatch searches near `offset` only.
    public static func resolve(
        markdown: String,
        proposedOffset: Int,
        proposedLength: Int,
        quotedText: String
    ) -> Resolved? {
        guard !quotedText.isEmpty else { return nil }
        guard proposedOffset >= 0, proposedLength > 0, proposedOffset + proposedLength <= markdown.utf16.count else {
            return nil
        }

        if sliceMatches(markdown: markdown, offset: proposedOffset, length: proposedLength, quotedText: quotedText) {
            return Resolved(offset: proposedOffset, length: proposedLength)
        }

        if let found = findQuotedText(markdown: markdown, quotedText: quotedText, near: proposedOffset, flexibleWhitespace: false) {
            return found
        }
        if let found = findQuotedText(markdown: markdown, quotedText: quotedText, near: proposedOffset, flexibleWhitespace: true) {
            return found
        }
        return nil
    }

    public static func sliceMatches(
        markdown: String,
        offset: Int,
        length: Int,
        quotedText: String
    ) -> Bool {
        let utf16 = Array(markdown.utf16)
        guard offset >= 0, length > 0, offset + length <= utf16.count else { return false }
        let sliceUnits = Array(utf16[offset ..< offset + length])
        let slice = String(utf16CodeUnits: sliceUnits, count: sliceUnits.count)
        if slice == quotedText { return true }
        return normalizeForSearch(slice) == normalizeForSearch(quotedText)
    }

    public static func findQuotedText(
        markdown: String,
        quotedText: String,
        near nearOffset: Int,
        flexibleWhitespace: Bool
    ) -> Resolved? {
        let needle = Array(normalizeForSearch(quotedText).utf16)
        guard !needle.isEmpty else { return nil }
        let hay = Array(markdown.utf16)
        guard needle.count <= hay.count else { return nil }

        var bestOffset: Int?
        var bestLength: Int?
        var bestDistance = Int.max
        var searchIndex = 0
        while searchIndex < hay.count {
            guard let matchLength = utf16MatchLength(
                hay: hay,
                start: searchIndex,
                needle: needle,
                flexibleWhitespace: flexibleWhitespace
            ) else {
                searchIndex += 1
                continue
            }
            let distance = abs(searchIndex - nearOffset)
            if distance < bestDistance {
                bestDistance = distance
                bestOffset = searchIndex
                bestLength = matchLength
            }
            searchIndex += 1
        }
        guard let bestOffset, let bestLength else { return nil }
        return Resolved(offset: bestOffset, length: bestLength)
    }

    private static func normalizeForSearch(_ text: String) -> String {
        var normalized = text
        let replacements: [(String, String)] = [
            ("\u{2018}", "'"), ("\u{2019}", "'"),
            ("\u{201C}", "\""), ("\u{201D}", "\""),
            ("\u{00A0}", " "),
            ("\u{2013}", "-"), ("\u{2014}", "-"),
        ]
        for (from, to) in replacements {
            normalized = normalized.replacingOccurrences(of: from, with: to)
        }
        return normalized
    }

    private static func utf16MatchLength(
        hay: [UInt16],
        start: Int,
        needle: [UInt16],
        flexibleWhitespace: Bool
    ) -> Int? {
        var hi = start
        var ni = 0
        while ni < needle.count {
            if hi >= hay.count { return nil }
            let hc = hay[hi]
            let nc = needle[ni]
            if normalizeUtf16Unit(hc) == normalizeUtf16Unit(nc) {
                hi += 1
                ni += 1
                continue
            }
            if flexibleWhitespace, isFlexibleWhitespace(hc), isFlexibleWhitespace(nc) {
                while hi < hay.count, isFlexibleWhitespace(hay[hi]) { hi += 1 }
                while ni < needle.count, isFlexibleWhitespace(needle[ni]) { ni += 1 }
                continue
            }
            return nil
        }
        return hi - start
    }

    private static func normalizeUtf16Unit(_ unit: UInt16) -> UInt16 {
        switch unit {
        case 0x2018, 0x2019: 0x27
        case 0x201C, 0x201D: 0x22
        case 0x00A0: 0x20
        case 0x2013, 0x2014: 0x2D
        default: unit
        }
    }

    private static func isFlexibleWhitespace(_ codeUnit: UInt16) -> Bool {
        codeUnit == 0x20 || codeUnit == 0x0A || codeUnit == 0x0D || codeUnit == 0x09
    }
}
