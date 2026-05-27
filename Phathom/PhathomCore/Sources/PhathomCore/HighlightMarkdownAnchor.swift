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

    public enum MatchQuality: String, Sendable, Equatable {
        case strict
        case plainFallback
        case envelopeOnly
    }

    public struct ResolvedSelection: Sendable, Equatable {
        public let offset: Int
        public let length: Int
        public let segments: [Segment]
        public let matchQuality: MatchQuality

        public init(offset: Int, length: Int, segments: [Segment], matchQuality: MatchQuality) {
            self.offset = offset
            self.length = length
            self.segments = segments
            self.matchQuality = matchQuality
        }
    }

    /// Maps visible `quotedText` from a DOM selection to markdown envelope + per-leaf segments.
    public static func resolveFromSelection(
        markdown: String,
        quotedText: String,
        hintMarkdownOffset: Int? = nil
    ) -> ResolvedSelection? {
        let trimmed = quotedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let index = VisibleLeafIndex.build(source: normalized)

        if let strict = resolveStrict(index: index, quotedText: trimmed, hint: hintMarkdownOffset) {
            return strict
        }
        if let plain = resolvePlainFallback(index: index, source: normalized, quotedText: trimmed, hint: hintMarkdownOffset) {
            return plain
        }
        if let envelope = resolveEnvelopeOnly(index: index, quotedText: trimmed, hint: hintMarkdownOffset) {
            return envelope
        }
        if let hintAnchored = resolveHintAnchoredFallback(index: index, quotedText: trimmed, hint: hintMarkdownOffset) {
            return hintAnchored
        }
        return nil
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

    // MARK: - resolveFromSelection tiers

    private static func resolveStrict(
        index: VisibleLeafIndex,
        quotedText: String,
        hint: Int?
    ) -> ResolvedSelection? {
        let matches = findAllVisibleMatches(in: index.visibleStream, quotedText: quotedText)
        guard !matches.isEmpty else { return nil }

        var candidates: [(envelopeOffset: Int, selection: ResolvedSelection)] = []
        for match in matches {
            guard let segments = index.segments(forVisibleUTF16Range: match.start ..< match.end),
                  !segments.isEmpty else { continue }
            let offset = segments.map(\.start).min()!
            let end = segments.map(\.end).max()!
            candidates.append((
                envelopeOffset: offset,
                selection: ResolvedSelection(
                    offset: offset,
                    length: end - offset,
                    segments: segments,
                    matchQuality: .strict
                )
            ))
        }
        guard !candidates.isEmpty else { return nil }

        if candidates.count == 1 {
            return candidates[0].selection
        }
        guard let hint else { return nil }
        return candidates.min(by: { abs($0.envelopeOffset - hint) < abs($1.envelopeOffset - hint) })?.selection
    }

    private static func resolvePlainFallback(
        index: VisibleLeafIndex,
        source: String,
        quotedText: String,
        hint: Int?
    ) -> ResolvedSelection? {
        let visibleMatches = findAllVisibleMatches(in: index.visibleStream, quotedText: quotedText)
        if visibleMatches.count > 1, hint == nil { return nil }

        let near = hint ?? 0
        guard let found = findQuotedText(markdown: source, quotedText: quotedText, near: near, flexibleWhitespace: false)
            ?? findQuotedText(markdown: source, quotedText: quotedText, near: near, flexibleWhitespace: true)
        else { return nil }

        // Cross-format envelopes are longer than visible quoted text; plain fallback is contiguous raw markdown only.
        guard found.length <= quotedText.utf16.count else { return nil }

        let segment = Segment(start: found.offset, end: found.offset + found.length)
        return ResolvedSelection(
            offset: found.offset,
            length: found.length,
            segments: [segment],
            matchQuality: .plainFallback
        )
    }

    private static func resolveEnvelopeOnly(
        index: VisibleLeafIndex,
        quotedText: String,
        hint: Int?
    ) -> ResolvedSelection? {
        let matches = findAllVisibleMatches(in: index.visibleStream, quotedText: quotedText)
        guard !matches.isEmpty else { return nil }

        return pickEnvelopeOnlyCandidate(index: index, matches: matches, hint: hint)
    }

    private static func resolveHintAnchoredFallback(
        index: VisibleLeafIndex,
        quotedText: String,
        hint: Int?
    ) -> ResolvedSelection? {
        guard let hint else { return nil }

        let matches = findCollapsedVisibleMatches(in: index.visibleStream, quotedText: quotedText)
        if !matches.isEmpty {
            return pickEnvelopeOnlyCandidate(index: index, matches: matches, hint: hint)
        }

        guard let anchorLeaf = index.leafNearestMarkdownOffset(hint) else { return nil }
        let map = buildCollapsedMap(for: index.visibleStream)
        let collapsedNeedle = normalizeFlexibleWhitespace(normalizeForSearch(quotedText))
        let nsNeedle = collapsedNeedle as NSString
        guard nsNeedle.length >= 8 else { return nil }

        let nsHay = map.collapsed as NSString
        let anchorVisible = anchorLeaf.visibleUTF16Start
        let minPrefix = max(8, nsNeedle.length / 2)
        var best: (start: Int, end: Int, length: Int)?

        for length in stride(from: nsNeedle.length, through: minPrefix, by: -1) {
            let prefix = nsNeedle.substring(with: NSRange(location: 0, length: length))
            var searchLocation = 0
            while searchLocation < nsHay.length {
                let found = nsHay.range(of: prefix, options: [], range: NSRange(location: searchLocation, length: nsHay.length - searchLocation))
                guard found.location != NSNotFound else { break }
                let cStart = found.location
                let cEnd = found.location + found.length
                guard cStart < map.rawStartAtCollapsed.count, cEnd > 0, cEnd - 1 < map.rawEndAtCollapsed.count else {
                    searchLocation = found.location + 1
                    continue
                }
                let rawStart = map.rawStartAtCollapsed[cStart]
                let rawEnd = map.rawEndAtCollapsed[cEnd - 1]
                let distance = abs(rawStart - anchorVisible)
                if best == nil || distance < abs(best!.start - anchorVisible) || (distance == abs(best!.start - anchorVisible) && length > best!.length) {
                    best = (rawStart, rawEnd, length)
                }
                searchLocation = found.location + 1
            }
        }

        guard let best else { return nil }
        guard let segments = index.fullLeafSegments(forVisibleUTF16Range: best.start ..< best.end),
              !segments.isEmpty else { return nil }
        let offset = segments.map(\.start).min()!
        let end = segments.map(\.end).max()!
        return ResolvedSelection(
            offset: offset,
            length: end - offset,
            segments: [],
            matchQuality: .envelopeOnly
        )
    }

    private static func pickEnvelopeOnlyCandidate(
        index: VisibleLeafIndex,
        matches: [(start: Int, end: Int)],
        hint: Int?
    ) -> ResolvedSelection? {
        var candidates: [(envelopeOffset: Int, selection: ResolvedSelection)] = []
        for match in matches {
            guard let segments = index.fullLeafSegments(forVisibleUTF16Range: match.start ..< match.end),
                  !segments.isEmpty else { continue }
            let offset = segments.map(\.start).min()!
            let end = segments.map(\.end).max()!
            candidates.append((
                envelopeOffset: offset,
                selection: ResolvedSelection(
                    offset: offset,
                    length: end - offset,
                    segments: [],
                    matchQuality: .envelopeOnly
                )
            ))
        }
        guard !candidates.isEmpty else { return nil }

        if candidates.count == 1 {
            return candidates[0].selection
        }
        if let hint {
            return candidates.min(by: { abs($0.envelopeOffset - hint) < abs($1.envelopeOffset - hint) })?.selection
        }
        return candidates[0].selection
    }

    private static func findAllVisibleMatches(in visibleStream: String, quotedText: String) -> [(start: Int, end: Int)] {
        for flexible in [false, true] {
            let results = findVisibleMatches(in: visibleStream, quotedText: quotedText, flexibleWhitespace: flexible)
            if !results.isEmpty { return results }
        }
        return findCollapsedVisibleMatches(in: visibleStream, quotedText: quotedText)
    }

    private static func findCollapsedVisibleMatches(
        in visibleStream: String,
        quotedText: String
    ) -> [(start: Int, end: Int)] {
        let map = buildCollapsedMap(for: visibleStream)
        let collapsedNeedle = normalizeFlexibleWhitespace(normalizeForSearch(quotedText))
        guard !collapsedNeedle.isEmpty, collapsedNeedle.utf16.count <= map.collapsed.utf16.count else { return [] }

        let nsHay = map.collapsed as NSString
        let nsNeedle = collapsedNeedle as NSString
        var results: [(start: Int, end: Int)] = []
        var searchLocation = 0
        while searchLocation < nsHay.length {
            let found = nsHay.range(of: nsNeedle as String, options: [], range: NSRange(location: searchLocation, length: nsHay.length - searchLocation))
            guard found.location != NSNotFound else { break }
            let cStart = found.location
            let cEnd = found.location + found.length
            guard cStart < map.rawStartAtCollapsed.count, cEnd > 0, cEnd - 1 < map.rawEndAtCollapsed.count else {
                searchLocation = found.location + 1
                continue
            }
            let rawStart = map.rawStartAtCollapsed[cStart]
            let rawEnd = map.rawEndAtCollapsed[cEnd - 1]
            results.append((start: rawStart, end: rawEnd))
            searchLocation = found.location + 1
        }
        return results
    }

    private struct CollapsedVisibleMap {
        let collapsed: String
        let rawStartAtCollapsed: [Int]
        let rawEndAtCollapsed: [Int]
    }

    private static func buildCollapsedMap(for visibleStream: String) -> CollapsedVisibleMap {
        let rawUnits = Array(visibleStream.utf16)
        var collapsedScalars: [UnicodeScalar] = []
        var rawStartAtCollapsed: [Int] = []
        var rawEndAtCollapsed: [Int] = []

        var index = 0
        var inWhitespace = false
        while index < rawUnits.count {
            let unit = normalizeUtf16Unit(rawUnits[index])
            if isFlexibleWhitespace(unit) {
                if !inWhitespace, !collapsedScalars.isEmpty {
                    collapsedScalars.append(" ")
                    rawStartAtCollapsed.append(index)
                    rawEndAtCollapsed.append(index + 1)
                    inWhitespace = true
                }
                index += 1
                continue
            }
            if inWhitespace, let last = rawEndAtCollapsed.indices.last {
                rawEndAtCollapsed[last] = index
                inWhitespace = false
            }
            if let scalar = UnicodeScalar(unit) {
                collapsedScalars.append(scalar)
                rawStartAtCollapsed.append(index)
                rawEndAtCollapsed.append(index + 1)
            }
            index += 1
        }

        while let first = collapsedScalars.first, CharacterSet.whitespacesAndNewlines.contains(first) {
            collapsedScalars.removeFirst()
            rawStartAtCollapsed.removeFirst()
            rawEndAtCollapsed.removeFirst()
        }
        while let last = collapsedScalars.last, CharacterSet.whitespacesAndNewlines.contains(last) {
            collapsedScalars.removeLast()
            rawStartAtCollapsed.removeLast()
            rawEndAtCollapsed.removeLast()
        }

        let collapsed = String(String.UnicodeScalarView(collapsedScalars))
        return CollapsedVisibleMap(
            collapsed: collapsed,
            rawStartAtCollapsed: rawStartAtCollapsed,
            rawEndAtCollapsed: rawEndAtCollapsed
        )
    }

    private static func findVisibleMatches(
        in visibleStream: String,
        quotedText: String,
        flexibleWhitespace: Bool
    ) -> [(start: Int, end: Int)] {
        let needle = Array(normalizeForSearch(quotedText).utf16)
        guard !needle.isEmpty else { return [] }
        let hay = Array(visibleStream.utf16)
        guard needle.count <= hay.count else { return [] }

        var results: [(start: Int, end: Int)] = []
        var searchIndex = 0
        while searchIndex < hay.count {
            if let matchLength = utf16MatchLength(
                hay: hay,
                start: searchIndex,
                needle: needle,
                flexibleWhitespace: flexibleWhitespace
            ) {
                results.append((start: searchIndex, end: searchIndex + matchLength))
            }
            searchIndex += 1
        }
        return results
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

// MARK: - Visible leaf index (mirrors SourceContentIndexer span leaves)

private struct VisibleLeaf {
    let mdStart: Int
    let mdEnd: Int
    let visibleText: String
    let visibleUTF16Start: Int

    var visibleUTF16End: Int { visibleUTF16Start + visibleText.utf16.count }
}

private struct VisibleLeafIndex {
    let leaves: [VisibleLeaf]
    let visibleStream: String

    static func build(source: String) -> VisibleLeafIndex {
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var builder = VisibleLeafIndexBuilder(source: source)
        builder.visit(document)
        return VisibleLeafIndex(leaves: builder.leaves, visibleStream: builder.visibleStream)
    }

    func leafNearestMarkdownOffset(_ offset: Int) -> VisibleLeaf? {
        guard !leaves.isEmpty else { return nil }
        if let containing = leaves.first(where: { offset >= $0.mdStart && offset < $0.mdEnd }) {
            return containing
        }
        return leaves.min(by: { abs($0.mdStart - offset) < abs($1.mdStart - offset) })
    }

    func segments(forVisibleUTF16Range range: Range<Int>) -> [HighlightMarkdownAnchor.Segment]? {
        var segments: [HighlightMarkdownAnchor.Segment] = []
        for leaf in leaves {
            let intersectionStart = max(range.lowerBound, leaf.visibleUTF16Start)
            let intersectionEnd = min(range.upperBound, leaf.visibleUTF16End)
            guard intersectionStart < intersectionEnd else { continue }

            let localStart = intersectionStart - leaf.visibleUTF16Start
            let localEnd = intersectionEnd - leaf.visibleUTF16Start
            let mdStart = leaf.mdStart + localStart
            let mdEnd = leaf.mdStart + localEnd
            guard mdEnd > mdStart else { continue }
            segments.append(HighlightMarkdownAnchor.Segment(start: mdStart, end: mdEnd))
        }
        return segments.isEmpty ? nil : segments
    }

    func fullLeafSegments(forVisibleUTF16Range range: Range<Int>) -> [HighlightMarkdownAnchor.Segment]? {
        var segments: [HighlightMarkdownAnchor.Segment] = []
        for leaf in leaves {
            guard leaf.visibleUTF16Start < range.upperBound, leaf.visibleUTF16End > range.lowerBound else { continue }
            segments.append(HighlightMarkdownAnchor.Segment(start: leaf.mdStart, end: leaf.mdEnd))
        }
        return segments.isEmpty ? nil : segments
    }
}

private struct VisibleLeafIndexBuilder: MarkupVisitor {
    typealias Result = Void

    let source: String
    private(set) var leaves: [VisibleLeaf] = []
    private(set) var visibleStream: String = ""
    private var siblingBlockActiveStack: [Bool] = []

    init(source: String) {
        self.source = source
    }

    mutating func defaultVisit(_ markup: any Markup) -> Void {
        for child in markup.children {
            visit(child)
        }
    }

    mutating func visitDocument(_ document: Document) -> Void {
        enterBlockContainer()
        for child in document.children {
            visit(child)
        }
        leaveBlockContainer()
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> Void {
        beginSiblingBlock()
        for child in paragraph.children {
            visit(child)
        }
    }

    mutating func visitHeading(_ heading: Heading) -> Void {
        beginSiblingBlock()
        for child in heading.children {
            visit(child)
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> Void {
        beginSiblingBlock()
        enterBlockContainer()
        for child in blockQuote.children {
            visit(child)
        }
        leaveBlockContainer()
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> Void {
        beginSiblingBlock()
        enterBlockContainer()
        for item in list.listItems {
            visit(item)
        }
        leaveBlockContainer()
    }

    mutating func visitOrderedList(_ list: OrderedList) -> Void {
        beginSiblingBlock()
        enterBlockContainer()
        for item in list.listItems {
            visit(item)
        }
        leaveBlockContainer()
    }

    mutating func visitListItem(_ item: ListItem) -> Void {
        beginSiblingBlock()
        for child in item.children {
            if let paragraph = child as? Paragraph {
                for inline in paragraph.children {
                    visit(inline)
                }
            } else {
                visit(child)
            }
        }
    }

    mutating func visitText(_ text: Text) -> Void {
        guard let range = text.range else { return }
        appendLeaf(visible: text.string, markdownRange: markdownUTF16Offsets(source: source, range: range))
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Void {
        guard let range = softBreak.range else { return }
        appendLeaf(visible: " ", markdownRange: markdownUTF16Offsets(source: source, range: range))
    }

    mutating func visitInlineCode(_ code: InlineCode) -> Void {
        guard let range = code.range else { return }
        let (start, end) = markdownUTF16Offsets(source: source, range: range)
        appendLeaf(visible: code.code, markdownRange: (start + 1, end - 1))
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Void {
        beginSiblingBlock()
        let code = codeBlock.code.trimmingCharacters(in: .newlines)
        guard !code.isEmpty, let range = codeBlock.range else { return }
        let (start, end) = markdownUTF16Offsets(source: source, range: range)
        let contentStart = findFenceContentStart(in: source, blockStart: start)
        let contentEnd = findFenceContentEnd(in: source, blockEnd: end)
        appendLeaf(visible: code, markdownRange: (contentStart, contentEnd))
    }

    private mutating func enterBlockContainer() {
        siblingBlockActiveStack.append(false)
    }

    private mutating func leaveBlockContainer() {
        if !siblingBlockActiveStack.isEmpty {
            siblingBlockActiveStack.removeLast()
        }
    }

    private mutating func beginSiblingBlock() {
        guard !siblingBlockActiveStack.isEmpty else { return }
        let depth = siblingBlockActiveStack.count - 1
        if siblingBlockActiveStack[depth] {
            appendBlockSeparator()
        } else {
            siblingBlockActiveStack[depth] = true
        }
    }

    private mutating func appendBlockSeparator() {
        visibleStream += "\n\n"
    }

    private mutating func appendLeaf(visible: String, markdownRange: (start: Int, end: Int)) {
        guard markdownRange.start < markdownRange.end, !visible.isEmpty else { return }
        leaves.append(VisibleLeaf(
            mdStart: markdownRange.start,
            mdEnd: markdownRange.end,
            visibleText: visible,
            visibleUTF16Start: visibleStream.utf16.count
        ))
        visibleStream += visible
    }

    private func findFenceContentStart(in source: String, blockStart: Int) -> Int {
        let utf16 = Array(source.utf16)
        var i = blockStart
        while i < utf16.count {
            if utf16[i] == 0x0A {
                return i + 1
            }
            i += 1
        }
        return blockStart
    }

    private func findFenceContentEnd(in source: String, blockEnd: Int) -> Int {
        let utf16 = Array(source.utf16)
        var i = blockEnd - 1
        while i > 0 && utf16[i] == 0x60 {
            i -= 1
        }
        while i > 0 && utf16[i] == 0x0A {
            i -= 1
        }
        return i + 1
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
        appendVisible(text.string, markdownRange: markdownUTF16Offsets(source: source, range: range))
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Void {
        guard let range = softBreak.range else { return }
        appendVisible(" ", markdownRange: markdownUTF16Offsets(source: source, range: range))
    }

    mutating func visitInlineCode(_ code: InlineCode) -> Void {
        guard let range = code.range else { return }
        let (start, end) = markdownUTF16Offsets(source: source, range: range)
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
}

private func markdownUTF16Offsets(source: String, range: SourceRange) -> (start: Int, end: Int) {
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

private func utf16Substring(_ string: String, start: Int, end: Int) -> String {
    let utf16 = Array(string.utf16)
    guard start >= 0, end <= utf16.count, start < end else { return "" }
    return String(utf16CodeUnits: Array(utf16[start ..< end]), count: end - start)
}
