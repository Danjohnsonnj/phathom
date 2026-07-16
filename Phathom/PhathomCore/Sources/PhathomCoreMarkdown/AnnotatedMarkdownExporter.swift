import Foundation

public struct HighlightExportInput: Sendable, Equatable {
    public let sourceMarkdownOffset: Int
    public let sourceMarkdownLength: Int
    public let sourceMarkdownSegmentsJSON: String?
    public let userNote: String?

    public init(
        sourceMarkdownOffset: Int,
        sourceMarkdownLength: Int,
        sourceMarkdownSegmentsJSON: String? = nil,
        userNote: String? = nil
    ) {
        self.sourceMarkdownOffset = sourceMarkdownOffset
        self.sourceMarkdownLength = sourceMarkdownLength
        self.sourceMarkdownSegmentsJSON = sourceMarkdownSegmentsJSON
        self.userNote = userNote
    }
}

public struct AnnotatedMarkdownExport: Sendable, Equatable {
    public let markdown: String
    public let suggestedFilename: String

    public init(markdown: String, suggestedFilename: String) {
        self.markdown = markdown
        self.suggestedFilename = suggestedFilename
    }
}

/// Builds shareable markdown from stored article source + highlight anchors.
public enum AnnotatedMarkdownExporter {
    private struct Span: Equatable {
        let start: Int
        let end: Int
    }

    private struct Insertion {
        let offset: Int
        let text: String
    }

    public static func export(
        title: String,
        sourceURL: URL?,
        sourceMarkdown: String,
        highlights: [HighlightExportInput],
        exportedAt: Date = .now
    ) -> AnnotatedMarkdownExport? {
        let normalized = sourceMarkdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let noteCount = highlights.filter { hasNote($0) }.count
        let header = buildHeader(
            title: title,
            sourceURL: sourceURL,
            highlightCount: highlights.count,
            noteCount: noteCount,
            exportedAt: exportedAt
        )

        let annotatedBody = annotateBody(normalized, highlights: highlights)
        let footnoteBlock = buildFootnoteBlock(highlights: highlights)
        let markdown: String
        if footnoteBlock.isEmpty {
            markdown = header + annotatedBody
        } else {
            markdown = header + annotatedBody + "\n\n" + footnoteBlock
        }

        return AnnotatedMarkdownExport(
            markdown: markdown,
            suggestedFilename: slugFilename(from: title)
        )
    }

    // MARK: - Header

    private static func buildHeader(
        title: String,
        sourceURL: URL?,
        highlightCount: Int,
        noteCount: Int,
        exportedAt: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"

        let sourceLine = sourceURL?.absoluteString ?? "—"
        return "# \(title)\n\n**Source:** \(sourceLine)\n**Exported:** \(formatter.string(from: exportedAt))\n**Highlights:** \(highlightCount) (\(noteCount) with notes)\n\n"
    }

    // MARK: - Body annotation

    private static func annotateBody(_ markdown: String, highlights: [HighlightExportInput]) -> String {
        guard !highlights.isEmpty else { return markdown }

        let footnoteNumbers = assignFootnoteNumbers(highlights: highlights)
        var wrappedRanges: [Range<Int>] = []
        var insertions: [Insertion] = []

        // Ascending offset: outer envelopes wrap before inner spans so overlap skip works.
        let sortedForApply = highlights.sorted {
            $0.sourceMarkdownOffset < $1.sourceMarkdownOffset
        }

        for highlight in sortedForApply {
            let spans = spansForHighlight(highlight, markdownUTF16Count: markdown.utf16.count)
            guard !spans.isEmpty else { continue }

            let envelopeEnd = highlight.sourceMarkdownOffset + highlight.sourceMarkdownLength
            let footnoteSuffix = footnoteReferenceSuffix(
                for: highlight,
                footnoteNumbers: footnoteNumbers
            )

            let maxSpanEnd = spans.map(\.end).max() ?? envelopeEnd
            var placedFootnote = false

            for span in spans.sorted(by: { $0.start > $1.start }) {
                guard span.start >= 0, span.end > span.start, span.end <= markdown.utf16.count else {
                    continue
                }

                let shouldWrap = !isFullyContained(span, in: wrappedRanges)
                if shouldWrap {
                    let closing: String
                    if !footnoteSuffix.isEmpty, span.end == maxSpanEnd {
                        closing = "==\(footnoteSuffix)"
                        placedFootnote = true
                    } else {
                        closing = "=="
                    }
                    insertions.append(Insertion(offset: span.end, text: closing))
                    insertions.append(Insertion(offset: span.start, text: "=="))
                    wrappedRanges.append(span.start ..< span.end)
                } else if !footnoteSuffix.isEmpty, span.end == maxSpanEnd, !placedFootnote {
                    insertions.append(Insertion(offset: span.end, text: footnoteSuffix))
                    placedFootnote = true
                }
            }

            if !footnoteSuffix.isEmpty, !placedFootnote {
                insertions.append(Insertion(offset: envelopeEnd, text: footnoteSuffix))
            }
        }

        return applyInsertions(to: markdown, insertions: insertions)
    }

    private static func footnoteReferenceSuffix(
        for highlight: HighlightExportInput,
        footnoteNumbers: [HighlightFootnoteKey: Int]
    ) -> String {
        guard hasNote(highlight) else { return "" }
        let key = HighlightFootnoteKey(
            offset: highlight.sourceMarkdownOffset,
            length: highlight.sourceMarkdownLength
        )
        guard let number = footnoteNumbers[key] else { return "" }
        return "[^\(number)]"
    }

    private struct HighlightFootnoteKey: Hashable {
        let offset: Int
        let length: Int
    }

    private static func assignFootnoteNumbers(highlights: [HighlightExportInput]) -> [HighlightFootnoteKey: Int] {
        var result: [HighlightFootnoteKey: Int] = [:]
        var number = 1
        for highlight in highlights.sorted(by: { $0.sourceMarkdownOffset < $1.sourceMarkdownOffset }) {
            guard hasNote(highlight) else { continue }
            let key = HighlightFootnoteKey(
                offset: highlight.sourceMarkdownOffset,
                length: highlight.sourceMarkdownLength
            )
            result[key] = number
            number += 1
        }
        return result
    }

    private static func spansForHighlight(_ highlight: HighlightExportInput, markdownUTF16Count: Int) -> [Span] {
        if let segments = decodeSegments(highlight.sourceMarkdownSegmentsJSON), !segments.isEmpty {
            return segments.compactMap { segment in
                guard segment.end > segment.start,
                      segment.start >= 0,
                      segment.end <= markdownUTF16Count else {
                    return nil
                }
                return Span(start: segment.start, end: segment.end)
            }
        }

        let start = highlight.sourceMarkdownOffset
        let end = start + highlight.sourceMarkdownLength
        guard start >= 0, end > start, end <= markdownUTF16Count else { return [] }
        return [Span(start: start, end: end)]
    }

    private static func decodeSegments(_ json: String?) -> [HighlightMarkdownAnchor.Segment]? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode([HighlightMarkdownAnchor.Segment].self, from: data),
              !decoded.isEmpty else {
            return nil
        }
        return decoded
    }

    private static func isFullyContained(_ span: Span, in ranges: [Range<Int>]) -> Bool {
        ranges.contains { range in
            range.lowerBound <= span.start && span.end <= range.upperBound
        }
    }

    private static func applyInsertions(to markdown: String, insertions: [Insertion]) -> String {
        guard !insertions.isEmpty else { return markdown }
        var units = Array(markdown.utf16)
        for insertion in insertions.sorted(by: { $0.offset > $1.offset }) {
            let inserted = Array(insertion.text.utf16)
            let offset = min(max(insertion.offset, 0), units.count)
            units.insert(contentsOf: inserted, at: offset)
        }
        return String(utf16CodeUnits: units, count: units.count)
    }

    // MARK: - Footnotes

    private static func buildFootnoteBlock(highlights: [HighlightExportInput]) -> String {
        let footnoteNumbers = assignFootnoteNumbers(highlights: highlights)
        guard !footnoteNumbers.isEmpty else { return "" }

        let sorted = highlights
            .filter { hasNote($0) }
            .sorted { $0.sourceMarkdownOffset < $1.sourceMarkdownOffset }

        let lines = sorted.compactMap { highlight -> String? in
            guard let note = highlight.userNote?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !note.isEmpty else {
                return nil
            }
            let key = HighlightFootnoteKey(
                offset: highlight.sourceMarkdownOffset,
                length: highlight.sourceMarkdownLength
            )
            guard let number = footnoteNumbers[key] else { return nil }
            return formatFootnoteDefinition(number: number, note: note)
        }

        return lines.joined(separator: "\n\n")
    }

    private static func formatFootnoteDefinition(number: Int, note: String) -> String {
        let parts = note.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = parts.first else { return "[^\(number)]: " }
        var result = "[^\(number)]: \(first)"
        for line in parts.dropFirst() {
            result += "\n    \(line)"
        }
        return result
    }

    private static func hasNote(_ highlight: HighlightExportInput) -> Bool {
        guard let note = highlight.userNote else { return false }
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Filename

    static func slugFilename(from title: String) -> String {
        let lowered = title.lowercased()
        var slug = ""
        var previousHyphen = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                previousHyphen = false
            } else if !previousHyphen {
                slug.append("-")
                previousHyphen = true
            }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty {
            slug = "article"
        }
        let maxStem = 80
        if slug.count > maxStem {
            slug = String(slug.prefix(maxStem)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        if slug.isEmpty {
            slug = "article"
        }
        return "\(slug).md"
    }
}
