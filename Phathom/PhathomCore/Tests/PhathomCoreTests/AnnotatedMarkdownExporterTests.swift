import PhathomCoreMarkdown
import XCTest

final class AnnotatedMarkdownExporterTests: XCTestCase {
    func testZeroHighlights_headerAndPristineBody() throws {
        let body = "First paragraph.\n\nSecond paragraph."
        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Example Article",
            sourceURL: URL(string: "https://example.com/post"),
            sourceMarkdown: body,
            highlights: [],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("# Example Article\n"))
        XCTAssertTrue(export.markdown.contains("**Source:** https://example.com/post"))
        XCTAssertTrue(export.markdown.contains("**Exported:** 2026-07-08"))
        XCTAssertTrue(export.markdown.contains("**Highlights:** 0 (0 with notes)"))
        XCTAssertTrue(export.markdown.hasSuffix(body))
        XCTAssertFalse(export.markdown.contains("=="))
        XCTAssertFalse(export.markdown.contains("[^"))
    }

    func testHighlightNoNote_inlineMarkOnly() throws {
        let body = "The quick brown fox."
        let offset = (body as NSString).range(of: "quick brown").location
        let length = ("quick brown" as NSString).length

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Fox",
            sourceURL: nil,
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: offset,
                    sourceMarkdownLength: length,
                    userNote: nil
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertEqual(export.markdown, """
        # Fox

        **Source:** —
        **Exported:** 2026-07-08
        **Highlights:** 1 (0 with notes)

        The ==quick brown== fox.
        """)
    }

    func testHighlightWithNote_inlineMarkAndFootnote() throws {
        let body = "The quick brown fox."
        let offset = (body as NSString).range(of: "quick brown").location
        let length = ("quick brown" as NSString).length

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Fox",
            sourceURL: URL(string: "https://example.com"),
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: offset,
                    sourceMarkdownLength: length,
                    userNote: "Key phrase for the draft."
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("The ==quick brown==[^1] fox."))
        XCTAssertTrue(export.markdown.hasSuffix("[^1]: Key phrase for the draft."))
    }

    func testSegmentedHighlight_multipleMarks() throws {
        let body = "Paragraph with **bold** word."
        let boldStart = (body as NSString).range(of: "bold").location
        let boldEnd = boldStart + ("bold" as NSString).length
        let wordStart = (body as NSString).range(of: "word").location
        let wordEnd = wordStart + ("word" as NSString).length
        let segmentsJSON = try XCTUnwrap(encodeSegments([
            HighlightMarkdownAnchor.Segment(start: boldStart, end: boldEnd),
            HighlightMarkdownAnchor.Segment(start: wordStart, end: wordEnd),
        ]))

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Segmented",
            sourceURL: nil,
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: boldStart,
                    sourceMarkdownLength: wordEnd - boldStart,
                    sourceMarkdownSegmentsJSON: segmentsJSON,
                    userNote: nil
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("Paragraph with **==bold==** ==word==."))
    }

    func testEnvelopeOnly_singleWrapWhenSegmentsNil() throws {
        let body = "Plain contiguous text."
        let offset = (body as NSString).range(of: "contiguous").location
        let length = ("contiguous" as NSString).length

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Envelope",
            sourceURL: nil,
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: offset,
                    sourceMarkdownLength: length,
                    sourceMarkdownSegmentsJSON: nil,
                    userNote: nil
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("Plain ==contiguous== text."))
    }

    func testFootnoteNumbering_forwardOffsetOrder() throws {
        let body = "Alpha beta gamma."
        let alpha = (body as NSString).range(of: "Alpha").location
        let beta = (body as NSString).range(of: "beta").location
        let gamma = (body as NSString).range(of: "gamma").location

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Notes",
            sourceURL: nil,
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: beta,
                    sourceMarkdownLength: ("beta" as NSString).length,
                    userNote: "Second in doc."
                ),
                HighlightExportInput(
                    sourceMarkdownOffset: alpha,
                    sourceMarkdownLength: ("Alpha" as NSString).length,
                    userNote: nil
                ),
                HighlightExportInput(
                    sourceMarkdownOffset: gamma,
                    sourceMarkdownLength: ("gamma" as NSString).length,
                    userNote: "Third in doc."
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("==Alpha== ==beta==[^1] ==gamma==[^2]."))
        XCTAssertTrue(export.markdown.contains("[^1]: Second in doc."))
        XCTAssertTrue(export.markdown.contains("[^2]: Third in doc."))
    }

    func testOverlapSkipInnerWrap_outerMarkInnerFootnote() throws {
        let body = "The quick brown fox jumps."
        let outerOffset = (body as NSString).range(of: "quick brown fox").location
        let outerLength = ("quick brown fox" as NSString).length
        let innerOffset = (body as NSString).range(of: "brown").location
        let innerLength = ("brown" as NSString).length

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Overlap",
            sourceURL: nil,
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: outerOffset,
                    sourceMarkdownLength: outerLength,
                    userNote: nil
                ),
                HighlightExportInput(
                    sourceMarkdownOffset: innerOffset,
                    sourceMarkdownLength: innerLength,
                    userNote: "Inner thought."
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("The ==quick brown[^1] fox== jumps."))
        XCTAssertFalse(export.markdown.contains("==brown=="))
        XCTAssertTrue(export.markdown.contains("brown[^1]"))
        XCTAssertTrue(export.markdown.hasSuffix("[^1]: Inner thought."))
    }

    func testFilenameSlug_punctuationAndSpaces() throws {
        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "The Future of Local LLMs (2026)!",
            sourceURL: nil,
            sourceMarkdown: "Body",
            highlights: [],
            exportedAt: fixtureDate
        ))

        XCTAssertEqual(export.suggestedFilename, "the-future-of-local-llms-2026.md")
    }

    func testMultilineFootnote_usesIndentedContinuation() throws {
        let body = "Marked text here."
        let offset = (body as NSString).range(of: "Marked").location
        let length = ("Marked" as NSString).length

        let export = try XCTUnwrap(AnnotatedMarkdownExporter.export(
            title: "Multiline",
            sourceURL: nil,
            sourceMarkdown: body,
            highlights: [
                HighlightExportInput(
                    sourceMarkdownOffset: offset,
                    sourceMarkdownLength: length,
                    userNote: "Line one.\nLine two."
                ),
            ],
            exportedAt: fixtureDate
        ))

        XCTAssertTrue(export.markdown.contains("[^1]: Line one.\n    Line two."))
    }

    // MARK: - Helpers

    private var fixtureDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = 2026
        components.month = 7
        components.day = 8
        components.hour = 12
        return components.date!
    }

    private func encodeSegments(_ segments: [HighlightMarkdownAnchor.Segment]) throws -> String {
        let data = try JSONEncoder().encode(segments)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }
}
