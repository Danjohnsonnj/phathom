import PhathomCore
import XCTest

final class HighlightMarkdownAnchorTests: XCTestCase {
    func testSliceMatches_exactUTF16() {
        let md = "Hello **world** today"
        XCTAssertTrue(HighlightMarkdownAnchor.sliceMatches(markdown: md, offset: 0, length: 6, quotedText: "Hello "))
    }

    func testResolve_acceptsVerifiedPayload() {
        let md = "The quick brown fox jumps."
        let quoted = "quick brown"
        let offset = (md as NSString).range(of: quoted).location
        let length = (quoted as NSString).length

        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: offset,
            proposedLength: length,
            quotedText: quoted
        )
        XCTAssertEqual(resolved?.offset, offset)
        XCTAssertEqual(resolved?.length, length)
    }

    func testFindQuotedText_prefersNearestOccurrence() {
        let md = "the cat sat. the dog ran."
        let near = (md as NSString).range(of: "the dog").location
        let resolved = HighlightMarkdownAnchor.findQuotedText(
            markdown: md,
            quotedText: "the dog",
            near: near,
            flexibleWhitespace: false
        )
        XCTAssertEqual(resolved?.offset, near)
        XCTAssertEqual(resolved?.length, ("the dog" as NSString).length)
    }

    func testFindQuotedText_flexibleWhitespaceNewlineVsSpace() {
        let md = "Line one\nLine two"
        let quoted = "one Line"
        let resolved = HighlightMarkdownAnchor.findQuotedText(
            markdown: md,
            quotedText: quoted,
            near: 0,
            flexibleWhitespace: true
        )
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.length, (quoted as NSString).length)
    }

    func testVisiblePlainText_matchesIndexerSpans() throws {
        let md = "Paragraph with **bold** word and [link](https://example.com) text."
        let indexed = try XCTUnwrap(SourceContentIndexer.index(markdown: md))
        let envelope = try XCTUnwrap(spanEnvelope(in: indexed.html, spanTexts: ["bold", " word and ", "link"]))
        let visible = try XCTUnwrap(HighlightMarkdownAnchor.visiblePlainText(
            markdown: md,
            offset: envelope.start,
            length: envelope.end - envelope.start
        ))
        XCTAssertEqual(visible, envelope.visibleFromSpans)
    }

    func testResolve_crossBoldAndPlain_envelopeAccepted() throws {
        let md = "Paragraph with **bold** word and [link](https://example.com) text."
        let indexed = try XCTUnwrap(SourceContentIndexer.index(markdown: md))
        let envelope = try XCTUnwrap(spanEnvelope(in: indexed.html, spanTexts: ["bold", " word and ", "link"]))
        let quoted = envelope.visibleFromSpans

        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: envelope.start,
            proposedLength: envelope.end - envelope.start,
            quotedText: quoted
        )
        XCTAssertEqual(resolved?.offset, envelope.start)
        XCTAssertEqual(resolved?.length, envelope.end - envelope.start)
    }

    func testResolve_crossLinkAndPlain_envelopeAccepted() throws {
        let md = "See [link](https://example.com) next."
        let indexed = try XCTUnwrap(SourceContentIndexer.index(markdown: md))
        let envelope = try XCTUnwrap(spanEnvelope(in: indexed.html, spanTexts: ["See ", "link"]))
        let quoted = envelope.visibleFromSpans

        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: envelope.start,
            proposedLength: envelope.end - envelope.start,
            quotedText: quoted
        )
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.offset, envelope.start)
    }

    func testResolve_segmentsMatchQuotedText_acceptsPerSpanUnion() throws {
        let md = "Words before [link text](https://example.com) after words."
        let indexed = try XCTUnwrap(SourceContentIndexer.index(markdown: md))
        let picked = try XCTUnwrap(spanEnvelope(
            in: indexed.html,
            spanTexts: ["Words before ", "link text", " after words."]
        ))
        let spans = try XCTUnwrap(spanRanges(
            in: indexed.html,
            spanTexts: ["Words before ", "link text", " after words."]
        ))
        let segments = spans.map { HighlightMarkdownAnchor.Segment(start: $0.start, end: $0.end) }
        let quoted = picked.visibleFromSpans

        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: picked.start,
            proposedLength: picked.end - picked.start,
            quotedText: quoted,
            segments: segments
        )
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.offset, picked.start)
        XCTAssertEqual(resolved?.length, picked.end - picked.start)
    }

    func testResolve_crossFormat_doesNotShrinkViaFindQuotedText() throws {
        let md = "Paragraph with **bold** word and [link](https://example.com) text."
        let indexed = try XCTUnwrap(SourceContentIndexer.index(markdown: md))
        let envelope = try XCTUnwrap(spanEnvelope(in: indexed.html, spanTexts: ["bold", " word and ", "link"]))
        let proposedLength = envelope.end - envelope.start
        let shortQuoted = "word"
        XCTAssertGreaterThan(proposedLength, (shortQuoted as NSString).length)

        let shrunk = HighlightMarkdownAnchor.findQuotedText(
            markdown: md,
            quotedText: shortQuoted,
            near: envelope.start,
            flexibleWhitespace: false
        )
        XCTAssertNotNil(shrunk)
        XCTAssertLessThan(shrunk!.length, proposedLength)

        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: envelope.start,
            proposedLength: proposedLength,
            quotedText: shortQuoted
        )
        XCTAssertNil(resolved)
    }

    func testResolve_envelopeFlexibleWhitespace() {
        let md = "Hello  world"
        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: 0,
            proposedLength: md.utf16.count,
            quotedText: "Hello world"
        )
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.offset, 0)
        XCTAssertEqual(resolved?.length, md.utf16.count)
    }

    func testResolve_crossBlock_envelopeAccepted() throws {
        let md = """
        First paragraph end.

        Second paragraph start.
        """
        let indexed = try XCTUnwrap(SourceContentIndexer.index(markdown: md))
        let envelope = try XCTUnwrap(spanEnvelope(in: indexed.html, spanTexts: ["First paragraph end.", "Second paragraph start."]))
        let quoted = envelope.visibleFromSpans

        let resolved = HighlightMarkdownAnchor.resolve(
            markdown: md,
            proposedOffset: envelope.start,
            proposedLength: envelope.end - envelope.start,
            quotedText: quoted
        )
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.offset, envelope.start)
        XCTAssertEqual(
            HighlightMarkdownAnchor.visiblePlainText(
                markdown: md,
                offset: envelope.start,
                length: envelope.end - envelope.start
            ),
            quoted
        )
    }

    // MARK: - Helpers

    private struct SpanEnvelope {
        let start: Int
        let end: Int
        let visibleFromSpans: String
    }

    private func spanEnvelope(in html: String, spanTexts: [String]) throws -> SpanEnvelope? {
        let pattern = #"data-md-start="(\d+)" data-md-end="(\d+)">([^<]*)</span>"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        var spans: [(start: Int, end: Int, text: String)] = []
        for match in matches {
            let startRange = Range(match.range(at: 1), in: html)!
            let endRange = Range(match.range(at: 2), in: html)!
            let textRange = Range(match.range(at: 3), in: html)!
            let text = String(html[textRange])
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
            spans.append((Int(html[startRange])!, Int(html[endRange])!, text))
        }

        spans.sort { $0.start < $1.start }
        let picked = spanTexts.compactMap { target in
            spans.first { $0.text == target }
        }
        guard picked.count == spanTexts.count else { return nil }
        let start = picked.first!.start
        let end = picked.last!.end
        let visible = picked.map(\.text).joined()
        return SpanEnvelope(start: start, end: end, visibleFromSpans: visible)
    }

    private func spanRanges(in html: String, spanTexts: [String]) throws -> [(start: Int, end: Int, text: String)]? {
        let pattern = #"data-md-start="(\d+)" data-md-end="(\d+)">([^<]*)</span>"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        var spans: [(start: Int, end: Int, text: String)] = []
        for match in matches {
            let startRange = Range(match.range(at: 1), in: html)!
            let endRange = Range(match.range(at: 2), in: html)!
            let textRange = Range(match.range(at: 3), in: html)!
            let text = String(html[textRange])
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
            spans.append((Int(html[startRange])!, Int(html[endRange])!, text))
        }

        spans.sort { $0.start < $1.start }
        let picked = spanTexts.compactMap { target in
            spans.first { $0.text == target }
        }
        guard picked.count == spanTexts.count else { return nil }
        return picked
    }
}
