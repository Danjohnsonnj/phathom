import PhathomCore
import XCTest

final class CategoryDisplayFormatterTests: XCTestCase {
    func testDisplayName_sentenceCaseHyphensBecomeSpaces() {
        XCTAssertEqual(CategoryDisplayFormatter.displayName("work-stuff"), "Work stuff")
    }

    func testNormalize_delegatesToTagRules_emptyReturnsNil() {
        XCTAssertNil(CategoryDisplayFormatter.normalize(" "))
    }

    func testNormalize_validKebabPasses() throws {
        let n = try XCTUnwrap(CategoryDisplayFormatter.normalize("Work Stuff"))
        XCTAssertEqual(n, "work-stuff")
    }

    func testNormalize_rejectsTooShortAfterNormalization() {
        XCTAssertNil(CategoryDisplayFormatter.normalize("x"))
    }
}
