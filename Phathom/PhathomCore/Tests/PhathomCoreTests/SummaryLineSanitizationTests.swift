import Foundation
import PhathomCore
import XCTest

final class SummaryLineSanitizationTests: XCTestCase {
    func testSourcePreview_under50Words_keepsNormalizedText() {
        let input = "  First line\n\nSecond line   with extra spacing.  "
        XCTAssertEqual(
            SummaryLineSanitization.sourcePreview(input, maxWords: 50),
            "First line Second line with extra spacing."
        )
    }

    func testSourcePreview_over50Words_truncatesToFirst50Words() {
        let input = (1...60).map { "w\($0)" }.joined(separator: " ")
        let preview = SummaryLineSanitization.sourcePreview(input, maxWords: 50)
        let expected = (1...50).map { "w\($0)" }.joined(separator: " ") + "..."
        XCTAssertEqual(preview, expected)
    }

    func testSourcePreview_whitespaceOnly_returnsNil() {
        XCTAssertNil(SummaryLineSanitization.sourcePreview(" \n\t ", maxWords: 50))
    }

    func testSourcePreview_nonPositiveMaxWords_returnsNil() {
        XCTAssertNil(SummaryLineSanitization.sourcePreview("hello world", maxWords: 0))
    }

    func testSourcePreview_markdownFormattedThenCapped() {
        let markdown = "# Heading\n- First item\n- Second item"
        XCTAssertEqual(
            SummaryLineSanitization.sourcePreview(markdown, maxWords: 3),
            "Heading First item..."
        )
    }

    func testSourceMarkdownPreview_preservesInlineMarkdown() {
        let markdown = "This has **bold** text and *emphasis* plus [link](https://example.com)."
        XCTAssertEqual(
            SummaryLineSanitization.sourceMarkdownPreview(markdown, maxWords: 20),
            "This has **bold** text and *emphasis* plus [link](https://example.com)."
        )
    }

    func testSourceMarkdownPreview_trimsDanglingLinkTail() {
        let markdown = "One two [three](https://example.com four five"
        XCTAssertEqual(
            SummaryLineSanitization.sourceMarkdownPreview(markdown, maxWords: 5),
            "One two"
        )
    }

    func testSourceMarkdownPreview_truncatedAppendsEllipsis() {
        let markdown = "One two **three** four five six"
        XCTAssertEqual(
            SummaryLineSanitization.sourceMarkdownPreview(markdown, maxWords: 4),
            "One two **three** four..."
        )
    }

    func testSourceMarkdownPreview_normalizesAllHeadingLevelsToFour() {
        let markdown = "# H1\n## H2\n###### H6"
        XCTAssertEqual(
            SummaryLineSanitization.sourceMarkdownPreview(markdown, maxWords: 20),
            "#### H1 #### H2 #### H6"
        )
    }

    func testSourceMarkdownPreview_mixedHeadingAndBodyPreservesBody() {
        let markdown = "## Subtitle\nBody line with **bold** text."
        XCTAssertEqual(
            SummaryLineSanitization.sourceMarkdownPreview(markdown, maxWords: 20),
            "#### Subtitle Body line with **bold** text."
        )
    }

    func testSourceMarkdownPreview_headingNormalizationWithTruncationAndEllipsis() {
        let markdown = "# Heading one two three four"
        XCTAssertEqual(
            SummaryLineSanitization.sourceMarkdownPreview(markdown, maxWords: 3),
            "#### Heading one..."
        )
    }
}
