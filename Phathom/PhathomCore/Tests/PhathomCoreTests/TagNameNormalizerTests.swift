import Foundation
import PhathomCore
import XCTest

final class TagNameNormalizerTests: XCTestCase {
    func testMixedCaseToLowercaseKebab() {
        XCTAssertEqual(TagNameNormalizer.normalize("AI"), "ai")
        XCTAssertEqual(TagNameNormalizer.normalize("Web Development"), "web-development")
    }

    func testHashtagPrefixAndUnderscores() {
        XCTAssertEqual(TagNameNormalizer.normalize("#climate_change"), "climate-change")
    }

    func testDiacriticsFolded() {
        XCTAssertEqual(TagNameNormalizer.normalize("café"), "cafe")
    }

    func testPunctuationStrippedToHyphens() {
        XCTAssertEqual(TagNameNormalizer.normalize("!!Recipe??"), "recipe")
    }

    func testLengthFiltering() {
        XCTAssertNil(TagNameNormalizer.normalize("a"))
        XCTAssertNil(TagNameNormalizer.normalize(""))
        let long = String(repeating: "x", count: 41)
        XCTAssertNil(TagNameNormalizer.normalize(long))
        XCTAssertEqual(TagNameNormalizer.normalize(String(repeating: "x", count: 40)), String(repeating: "x", count: 40))
    }

    func testNormalizeManyOrderPreservingDedupe() {
        let raw = ["AI", "ai", "Web Development", "web-development", "news"]
        XCTAssertEqual(TagNameNormalizer.normalize(many: raw), ["ai", "web-development", "news"])
    }
}
