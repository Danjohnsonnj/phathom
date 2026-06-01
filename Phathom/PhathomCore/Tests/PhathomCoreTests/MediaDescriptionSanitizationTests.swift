import XCTest
@testable import PhathomCore

final class MediaDescriptionSanitizationTests: XCTestCase {
    func testClean_stripsBoilerplateOpenerAndCapitalizes() {
        XCTAssertEqual(
            MediaDescriptionSanitization.clean("This image shows a cat."),
            "A cat."
        )
    }

    func testClean_stripsOpenerAndKeepsSecondSentence() {
        XCTAssertEqual(
            MediaDescriptionSanitization.clean("This image shows a settings page. Title bar reads Settings."),
            "A settings page. Title bar reads Settings."
        )
    }

    func testClean_dropsEmptyTextFillerSecondSentence() {
        XCTAssertEqual(
            MediaDescriptionSanitization.clean("Beach at sunset. No visible text."),
            "Beach at sunset."
        )
    }

    func testClean_dropsSingleSentenceEmptyTextFiller() {
        XCTAssertEqual(
            MediaDescriptionSanitization.clean("No visible text."),
            ""
        )
    }

    func testClean_fallsBackWhenOpenerStripWouldEmptyCaption() {
        XCTAssertEqual(
            MediaDescriptionSanitization.clean("This image shows"),
            "This image shows"
        )
    }

    func testClean_keepsTwoValidSentences() {
        let input = "Screenshot of a settings page. Title bar reads Settings."
        XCTAssertEqual(MediaDescriptionSanitization.clean(input), input)
    }

    func testClean_truncatesToTwoSentences() {
        XCTAssertEqual(
            MediaDescriptionSanitization.clean("One. Two. Three."),
            "One. Two."
        )
    }

    func testClean_emptyInputReturnsEmptyString() {
        XCTAssertEqual(MediaDescriptionSanitization.clean(""), "")
        XCTAssertEqual(MediaDescriptionSanitization.clean("   \n\t  "), "")
    }

    /// v1 naive split may break abbreviations — documents current behavior for text-heavy captions.
    func testClean_v1AbbreviationSplitIsNaive() {
        let result = MediaDescriptionSanitization.clean("Receipt from Dr. Smith at the clinic.")
        XCTAssertEqual(result, "Receipt from Dr. Smith at the clinic.")
    }
}
