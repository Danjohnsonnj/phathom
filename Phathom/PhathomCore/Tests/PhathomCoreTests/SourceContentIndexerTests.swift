import PhathomCore
import XCTest

final class SourceContentIndexerTests: XCTestCase {
    // MARK: - Heading and paragraph

    func testHeadingAndParagraph() throws {
        let md = """
        # Title Here

        Body paragraph text.
        """
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<h1>"))
        XCTAssertTrue(result.html.contains("</h1>"))
        XCTAssertTrue(result.html.contains("<p>"))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "Title Here")
        try assertSpanText(html: result.html, markdown: md, expected: "Body paragraph text.")
    }

    // MARK: - Bold and link

    func testBoldAndLink() throws {
        let md = "Text with **bold** and [link](https://example.com) here."
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<strong>"))
        XCTAssertTrue(result.html.contains("<a href=\"https://example.com\">"))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "bold")
        try assertSpanText(html: result.html, markdown: md, expected: "link")
    }

    // MARK: - List

    func testUnorderedList() throws {
        let md = """
        - Alpha item
        - Beta item
        """
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<ul>"))
        XCTAssertTrue(result.html.contains("<li>"))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "Alpha item")
        try assertSpanText(html: result.html, markdown: md, expected: "Beta item")
    }

    // MARK: - Blockquote

    func testBlockquote() throws {
        let md = "> Quoted words here"
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<blockquote>"))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "Quoted words here")
    }

    // MARK: - Inline code

    func testInlineCode() throws {
        let md = "Use `tick` here."
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<code>"))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "tick")
    }

    // MARK: - Code fence

    func testCodeFence() throws {
        let md = """
        ```
        println("hi")
        ```
        """
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<pre><code>"))
        try assertAllSpansValid(html: result.html, markdown: md)
    }

    // MARK: - Table

    func testTable() throws {
        let md = """
        | Col A | Col B |
        | ----- | ----- |
        | r1a   | r1b   |
        """
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<table>"))
        XCTAssertTrue(result.html.contains("<th>"))
        XCTAssertTrue(result.html.contains("<td>"))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "Col A")
        try assertSpanText(html: result.html, markdown: md, expected: "r1a")
    }

    // MARK: - Empty/nil handling

    func testEmptyMarkdownReturnsNil() {
        XCTAssertNil(SourceContentIndexer.index(markdown: ""))
        XCTAssertNil(SourceContentIndexer.index(markdown: "   \n\n  "))
    }

    // MARK: - Version

    func testVersionIsSet() throws {
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: "# Test"))
        XCTAssertEqual(result.version, SourceContentIndexer.currentVersion)
    }

    // MARK: - Spike fixture parity

    func testSpikeFixtureMarkdown() throws {
        let md = """
        # Spike Title

        Paragraph with **bold** word and [link](https://example.com) text.

        - Alpha item
        - Beta item

        > Quoted words

        Inline `tick` code.
        """
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        try assertAllSpansValid(html: result.html, markdown: md)
        try assertSpanText(html: result.html, markdown: md, expected: "Spike Title")
        try assertSpanText(html: result.html, markdown: md, expected: "bold")
        try assertSpanText(html: result.html, markdown: md, expected: "link")
        try assertSpanText(html: result.html, markdown: md, expected: "Alpha item")
        try assertSpanText(html: result.html, markdown: md, expected: "Quoted words")
        try assertSpanText(html: result.html, markdown: md, expected: "tick")
    }

    // MARK: - CRLF line endings

    func testCRLFLineEndingsRoundTrip() throws {
        let md = "# Heading\r\n\r\nBody text here."
        let result = try XCTUnwrap(SourceContentIndexer.index(markdown: md))

        XCTAssertTrue(result.html.contains("<h1>"))
        XCTAssertTrue(result.html.contains("<p>"))

        // Indexer normalizes CRLF→LF internally; offsets are into normalized string
        let normalized = md.replacingOccurrences(of: "\r\n", with: "\n")
        try assertAllSpansValid(html: result.html, markdown: normalized)
        try assertSpanText(html: result.html, markdown: normalized, expected: "Heading")
        try assertSpanText(html: result.html, markdown: normalized, expected: "Body text here.")
    }

    // MARK: - Helpers

    private func assertAllSpansValid(html: String, markdown: String, file: StaticString = #file, line: UInt = #line) throws {
        let pattern = #"data-md-start="(\d+)" data-md-end="(\d+)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        let mdLen = markdown.utf16.count
        for match in matches {
            let startRange = Range(match.range(at: 1), in: html)!
            let endRange = Range(match.range(at: 2), in: html)!
            let start = Int(html[startRange])!
            let end = Int(html[endRange])!

            XCTAssertGreaterThanOrEqual(start, 0, "start < 0", file: file, line: line)
            XCTAssertLessThan(start, end, "start >= end", file: file, line: line)
            XCTAssertLessThanOrEqual(end, mdLen, "end > markdown.utf16.count", file: file, line: line)
        }
    }

    private func assertSpanText(html: String, markdown: String, expected: String, file: StaticString = #file, line: UInt = #line) throws {
        let pattern = #"data-md-start="(\d+)" data-md-end="(\d+)">([^<]*)</span>"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            let textRange = Range(match.range(at: 3), in: html)!
            let spanText = String(html[textRange])
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")

            if spanText == expected {
                let startRange = Range(match.range(at: 1), in: html)!
                let endRange = Range(match.range(at: 2), in: html)!
                let start = Int(html[startRange])!
                let end = Int(html[endRange])!

                let mdUTF16 = Array(markdown.utf16)
                guard start >= 0, end <= mdUTF16.count, start < end else {
                    XCTFail("Invalid range for '\(expected)': [\(start), \(end))", file: file, line: line)
                    return
                }

                let slice = mdUTF16[start ..< end]
                let mdSubstring = String(utf16CodeUnits: Array(slice), count: slice.count)
                XCTAssertEqual(mdSubstring, expected, "Markdown slice mismatch for '\(expected)'", file: file, line: line)
                return
            }
        }
        XCTFail("Span with text '\(expected)' not found in HTML", file: file, line: line)
    }
}
