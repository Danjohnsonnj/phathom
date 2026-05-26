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
        XCTAssertEqual(resolved?.length, ( "the dog" as NSString).length)
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
}
