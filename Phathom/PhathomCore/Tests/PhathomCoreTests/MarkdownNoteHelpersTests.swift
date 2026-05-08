import Foundation
import PhathomCore
import XCTest

final class MarkdownNoteHelpersTests: XCTestCase {
    func testPlainSnippet_stripsHeadingAndListMarkers() {
        let markdown = """
        # Heading
        - First bullet
        1. Numbered point
        + Plus bullet
        """
        XCTAssertEqual(
            MarkdownNoteHelpers.plainSnippet(from: markdown),
            "Heading First bullet Numbered point Plus bullet"
        )
    }

    func testPlainSnippet_collapsesWhitespaceAndNewlines() {
        let markdown = "  Alpha   beta\n\n gamma\t delta  "
        XCTAssertEqual(MarkdownNoteHelpers.plainSnippet(from: markdown), "Alpha beta gamma delta")
    }
}
