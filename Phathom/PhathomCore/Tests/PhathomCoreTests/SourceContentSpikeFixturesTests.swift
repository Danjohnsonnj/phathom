import XCTest

/// UTF-16 offset invariants for spike hand-built HTML (mirrors app `SourceContentSpikeFixtures.canonicalMarkdown`).
final class SourceContentSpikeFixturesTests: XCTestCase {
    private let markdown = """
    # Spike Title

    Paragraph with **bold** word and [link](https://example.com) text.

    - Alpha item
    - Beta item

    > Quoted words

    Inline `tick` code.
    """.trimmingCharacters(in: .whitespacesAndNewlines)

    private func utf16Range(of needle: String) -> Range<Int> {
        guard let range = markdown.range(of: needle) else {
            XCTFail("missing needle: \(needle)")
            return 0..<0
        }
        let start = markdown.utf16.distance(
            from: markdown.utf16.startIndex,
            to: range.lowerBound.samePosition(in: markdown.utf16)!
        )
        let end = markdown.utf16.distance(
            from: markdown.utf16.startIndex,
            to: range.upperBound.samePosition(in: markdown.utf16)!
        )
        return start..<end
    }

    private func visibleSubstring(_ range: Range<Int>) -> String {
        let utf16 = markdown.utf16
        let start = utf16.index(utf16.startIndex, offsetBy: range.lowerBound)
        let end = utf16.index(utf16.startIndex, offsetBy: range.upperBound)
        return String(utf16[start..<end]) ?? ""
    }

    func testVisibleSpansExcludeMarkdownSyntax() {
        XCTAssertEqual(visibleSubstring(utf16Range(of: "bold")), "bold")
        XCTAssertEqual(visibleSubstring(utf16Range(of: "link")), "link")
        XCTAssertFalse(visibleSubstring(utf16Range(of: "bold")).contains("*"))
        XCTAssertFalse(visibleSubstring(utf16Range(of: "link")).contains("]("))
    }

    func testUtf16BoundsWithinMarkdown() {
        for needle in ["Spike Title", "bold", "link", "Alpha item", "Quoted words", "tick"] {
            let r = utf16Range(of: needle)
            XCTAssertGreaterThanOrEqual(r.lowerBound, 0)
            XCTAssertLessThanOrEqual(r.upperBound, markdown.utf16.count)
            XCTAssertLessThan(r.lowerBound, r.upperBound)
        }
    }

    func testTrimmedCanonicalHasNoLeadingTrailingWhitespace() {
        XCTAssertEqual(markdown.first, "#")
        XCTAssertFalse(markdown.hasPrefix(" "))
        XCTAssertFalse(markdown.hasSuffix(" "))
    }
}
