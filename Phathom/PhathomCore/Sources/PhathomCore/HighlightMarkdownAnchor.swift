import Foundation
import Markdown

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

    /// Visible plain text for markdown leaves intersecting `[offset, offset+length)` (matches `SourceContentIndexer` spans).
    public static func visiblePlainText(markdown: String, offset: Int, length: Int) -> String? {
        guard offset >= 0, length > 0, offset + length <= markdown.utf16.count else { return nil }
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let document = Document(parsing: normalized, options: [.parseBlockDirectives, .parseSymbolLinks])
        var visitor = VisiblePlainTextVisitor(
            source: normalized,
            envelopeStart: offset,
            envelopeEnd: offset + length
        )
        visitor.visit(document)
        let result = visitor.plainText
        return result.isEmpty ? nil : result
    }

    /// Verifies `quotedText` against `markdown[offset..<offset+length]`; on mismatch searches near `offset` only.
    public static func resolve(
        markdown: String,
        proposedOffset: Int,
        proposedLength: Int,
        quotedText: String,
        segments: [Segment]? = nil
    ) -> Resolved? {
        guard !quotedText.isEmpty else { return nil }
        guard proposedOffset >= 0, proposedLength > 0, proposedOffset + proposedLength <= markdown.utf16.count else {
            return nil
        }

        if sliceMatches(markdown: markdown, offset: proposedOffset, length: proposedLength, quotedText: quotedText) {
            return Resolved(offset: proposedOffset, length: proposedLength)
        }

        if envelopeMatches(
            markdown: markdown,
            offset: proposedOffset,
            length: proposedLength,
            quotedText: quotedText
        ) {
            return Resolved(offset: proposedOffset, length: proposedLength)
        }

        if segmentsMatchQuotedText(markdown: markdown, segments: segments, quotedText: quotedText) {
            return Resolved(offset: proposedOffset, length: proposedLength)
        }

        // Cross-format envelopes include markdown syntax between visible spans; never shrink via findQuotedText.
        if proposedLength > quotedText.utf16.count {
            return nil
        }
        if !quotedTextExistsContiguouslyInMarkdown(markdown: markdown, quotedText: quotedText) {
            return nil
        }

        if let found = findQuotedText(markdown: markdown, quotedText: quotedText, near: proposedOffset, flexibleWhitespace: false) {
            return found
        }
        if let found = findQuotedText(markdown: markdown, quotedText: quotedText, near: proposedOffset, flexibleWhitespace: true) {
            return found
        }
        return nil
    }

    public struct Segment: Sendable, Equatable, Codable {
        public let start: Int
        public let end: Int

        public init(start: Int, end: Int) {
            self.start = start
            self.end = end
        }
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

    private static func envelopeMatches(
        markdown: String,
        offset: Int,
        length: Int,
        quotedText: String
    ) -> Bool {
        guard let visible = visiblePlainText(markdown: markdown, offset: offset, length: length) else { return false }
        let lhs = normalizeFlexibleWhitespace(normalizeForSearch(visible))
        let rhs = normalizeFlexibleWhitespace(normalizeForSearch(quotedText))
        return lhs == rhs
    }

    private static func segmentsMatchQuotedText(
        markdown: String,
        segments: [Segment]?,
        quotedText: String
    ) -> Bool {
        guard let segments, !segments.isEmpty else { return false }
        var visible = ""
        for segment in segments {
            guard segment.end > segment.start else { return false }
            guard let slice = visiblePlainText(
                markdown: markdown,
                offset: segment.start,
                length: segment.end - segment.start
            ) else {
                return false
            }
            visible += slice
        }
        let lhs = normalizeFlexibleWhitespace(normalizeForSearch(visible))
        let rhs = normalizeFlexibleWhitespace(normalizeForSearch(quotedText))
        return lhs == rhs
    }

    private static func quotedTextExistsContiguouslyInMarkdown(markdown: String, quotedText: String) -> Bool {
        let needle = normalizeForSearch(quotedText)
        guard !needle.isEmpty else { return false }
        return normalizeForSearch(markdown).contains(needle)
    }

    private static func normalizeFlexibleWhitespace(_ text: String) -> String {
        var result = ""
        var inWhitespace = false
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !inWhitespace {
                    result.append(" ")
                    inWhitespace = true
                }
            } else {
                result.unicodeScalars.append(scalar)
                inWhitespace = false
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Visible plain text extraction (mirrors SourceContentIndexer span leaves)

private struct VisiblePlainTextVisitor: MarkupVisitor {
    typealias Result = Void

    let source: String
    let envelopeStart: Int
    let envelopeEnd: Int
    private(set) var plainText: String = ""

    mutating func defaultVisit(_ markup: any Markup) -> Void {
        for child in markup.children {
            visit(child)
        }
    }

    mutating func visitText(_ text: Text) -> Void {
        guard let range = text.range else { return }
        appendVisible(text.string, markdownRange: utf16Offsets(for: range))
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Void {
        guard let range = softBreak.range else { return }
        appendVisible(" ", markdownRange: utf16Offsets(for: range))
    }

    mutating func visitInlineCode(_ code: InlineCode) -> Void {
        guard let range = code.range else { return }
        let (start, end) = utf16Offsets(for: range)
        appendVisible(code.code, markdownRange: (start + 1, end - 1))
    }

    private mutating func appendVisible(_ visible: String, markdownRange: (start: Int, end: Int)) {
        let clipStart = max(markdownRange.start, envelopeStart)
        let clipEnd = min(markdownRange.end, envelopeEnd)
        guard clipStart < clipEnd else { return }
        let localStart = clipStart - markdownRange.start
        let localEnd = clipEnd - markdownRange.start
        plainText += utf16Substring(visible, start: localStart, end: localEnd)
    }

    private func utf16Offsets(for range: SourceRange) -> (start: Int, end: Int) {
        let startLine = range.lowerBound.line - 1
        let startCol = range.lowerBound.column - 1
        let endLine = range.upperBound.line - 1
        let endCol = range.upperBound.column - 1

        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

        var startOffset = 0
        for i in 0 ..< startLine where i < lines.count {
            startOffset += lines[i].utf16.count + 1
        }
        if startLine < lines.count {
            let line = lines[startLine]
            let colOffset = min(startCol, line.utf16.count)
            startOffset += colOffset
        }

        var endOffset = 0
        for i in 0 ..< endLine where i < lines.count {
            endOffset += lines[i].utf16.count + 1
        }
        if endLine < lines.count {
            let line = lines[endLine]
            let colOffset = min(endCol, line.utf16.count)
            endOffset += colOffset
        }

        return (startOffset, endOffset)
    }
}

private func utf16Substring(_ string: String, start: Int, end: Int) -> String {
    let utf16 = Array(string.utf16)
    guard start >= 0, end <= utf16.count, start < end else { return "" }
    return String(utf16CodeUnits: Array(utf16[start ..< end]), count: end - start)
}
