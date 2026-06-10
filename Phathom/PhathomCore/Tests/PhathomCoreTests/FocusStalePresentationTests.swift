import PhathomCore
import SwiftData
import XCTest

final class FocusStalePresentationTests: XCTestCase {
    func testStaleIntensityZeroBelowSevenDays() {
        XCTAssertEqual(FocusStalePresentation.staleIntensity(daysUntouched: 0), 0)
        XCTAssertEqual(FocusStalePresentation.staleIntensity(daysUntouched: 6), 0)
    }

    func testStaleIntensityRampsFromSevenDays() {
        XCTAssertEqual(FocusStalePresentation.staleIntensity(daysUntouched: 7), 1.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(FocusStalePresentation.staleIntensity(daysUntouched: 13), 1.0, accuracy: 0.0001)
        XCTAssertEqual(FocusStalePresentation.staleIntensity(daysUntouched: 20), 1.0, accuracy: 0.0001)
    }

    func testUntouchedLabelNilBelowThreshold() {
        XCTAssertNil(FocusStalePresentation.untouchedLabel(daysUntouched: 6))
    }

    func testUntouchedLabelFromSevenDays() {
        XCTAssertEqual(FocusStalePresentation.untouchedLabel(daysUntouched: 7), "Untouched 7 days")
        XCTAssertEqual(FocusStalePresentation.untouchedLabel(daysUntouched: 13), "Untouched 13 days")
    }

    func testNudgeCandidatePicksMostStaleEntry() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let mild = makeFocusItem(context: context, title: "mild")
        let severe = makeFocusItem(context: context, title: "severe")
        try context.save()

        let mildEntry = try XCTUnwrap(mild.focusEntry)
        let severeEntry = try XCTUnwrap(severe.focusEntry)
        mildEntry.lastTouchedAt = Date(timeIntervalSince1970: 0)
        severeEntry.lastTouchedAt = Date(timeIntervalSince1970: 0)
        mildEntry.addedAt = Date(timeIntervalSince1970: 0)
        severeEntry.addedAt = Date(timeIntervalSince1970: 0)
        try context.save()

        let now = Date(timeIntervalSince1970: 86400 * 10)
        mildEntry.lastTouchedAt = now.addingTimeInterval(-86400 * 7)
        severeEntry.lastTouchedAt = now.addingTimeInterval(-86400 * 12)

        let picked = FocusStalePresentation.nudgeCandidate(
            among: [mildEntry, severeEntry],
            dismissedKeys: [],
            now: now
        )
        XCTAssertEqual(picked?.id, severeEntry.id)
    }

    func testNudgeCandidateSkipsDismissedKey() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeFocusItem(context: context, title: "one")
        try context.save()

        let entry = try XCTUnwrap(item.focusEntry)
        let now = Date(timeIntervalSince1970: 86400 * 10)
        entry.lastTouchedAt = now.addingTimeInterval(-86400 * 8)

        let key = FocusStalePresentation.nudgeDismissalKey(for: entry)
        let picked = FocusStalePresentation.nudgeCandidate(
            among: [entry],
            dismissedKeys: [key],
            now: now
        )
        XCTAssertNil(picked)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = PhathomModelContainer.currentSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeFocusItem(context: ModelContext, title: String) -> ContentItem {
        let item = ContentItem(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 100),
            contentKind: .web,
            originalURL: URL(string: "https://example.com/\(title)")!
        )
        item.title = title
        context.insert(item)
        try! FocusStackService.addToFocus(item: item, in: context)
        return item
    }
}
