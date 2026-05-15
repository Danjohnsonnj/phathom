import Foundation
import PhathomCore
import XCTest

final class MarkdownPlainDecorationTests: XCTestCase {
    func testPlain_matchesStripperGoldens() {
        let cases: [(String, String)] = [
            ("# Hello **world**", "Hello world"),
            ("[`code`](https://a.com)", "code"),
            ("[link text](https://example.com/path)", "link text"),
            ("![alt](https://img)", "alt"),
            ("`x` and **y**", "x and y"),
            ("  spaced  \n\n", "spaced"),
            (
                """
                ```swift
                let a = 1
                ```
                After
                """,
                "After",
            ),
        ]

        for (input, expected) in cases {
            let got = MarkdownPlainDecoration.makePlain(from: input)
            XCTAssertEqual(got, expected, "input: \(input)")
        }
    }

    func testBuild_runsStayInPlainBounds() {
        let md = "# T\n\nHello [`c`](u) **b** [z](https://z)"
        let (plain, runs) = MarkdownPlainDecoration.build(from: md)
        XCTAssertFalse(plain.isEmpty)
        let n = (plain as NSString).length
        for run in runs {
            XCTAssertGreaterThanOrEqual(run.utf16Range.location, 0)
            XCTAssertLessThanOrEqual(NSMaxRange(run.utf16Range), n)
            XCTAssertGreaterThan(run.utf16Range.length, 0)
        }
    }

    func testLinkInsideBold_preservesLinkRunAfterBoldStrip() {
        let md = "[**inner**](https://x.test)"
        let (plain, runs) = MarkdownPlainDecoration.build(from: md)
        XCTAssertEqual(plain, "inner")
        let linkRuns = runs.filter { $0.traits.contains(.link) }
        XCTAssertEqual(linkRuns.count, 1)
        XCTAssertEqual(linkRuns[0].utf16Range, NSRange(location: 0, length: (plain as NSString).length))
        XCTAssertEqual(linkRuns[0].linkURL?.absoluteString, "https://x.test")
    }
}
