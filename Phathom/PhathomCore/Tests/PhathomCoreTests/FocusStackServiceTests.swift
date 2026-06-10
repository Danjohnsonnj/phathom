import PhathomCore
import SwiftData
import XCTest

final class FocusStackServiceTests: XCTestCase {
    func testAddToFocusUnderCapCreatesEntryWithMatchingTouchClock() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try FocusStackService.addToFocus(item: item, in: context, now: now)
        try context.save()

        XCTAssertTrue(FocusStackService.isInFocus(item))
        XCTAssertEqual(item.focusEntry?.addedAt, now)
        XCTAssertEqual(item.focusEntry?.lastTouchedAt, now)
        XCTAssertEqual(item.focusEntry?.sortOrder, 0)
        XCTAssertEqual(try FocusStackService.countActive(in: context), 1)
    }

    func testAddToFocusAtCapThrowsCapFull() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        for index in 0 ..< FocusStackConstants.maxActiveEntries {
            let item = makeItem(title: "item-\(index)")
            context.insert(item)
            try FocusStackService.addToFocus(item: item, in: context)
        }
        try context.save()

        let overflow = makeItem(title: "overflow")
        context.insert(overflow)
        XCTAssertThrowsError(try FocusStackService.addToFocus(item: overflow, in: context)) { error in
            XCTAssertEqual(error as? FocusStackError, .capFull)
        }
    }

    func testRemoveFromFocusDeletesEntryWithoutOutcomeByDefault() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        try context.save()

        try FocusStackService.removeFromFocus(item: item, in: context)
        try context.save()

        XCTAssertFalse(FocusStackService.isInFocus(item))
        XCTAssertTrue(item.focusOutcomes.isEmpty)
    }

    func testRemoveFromFocusLogReleaseWritesOutcome() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        try context.save()

        try FocusStackService.removeFromFocus(item: item, in: context, logRelease: true)
        try context.save()

        XCTAssertEqual(item.focusOutcomes.count, 1)
        XCTAssertEqual(item.focusOutcomes.first?.kind, .release)
    }

    func testCompleteOutcomeReferenceFilesAndRemovesFocus() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        try context.save()

        try FocusStackService.completeOutcome(item: item, kind: .reference, in: context)
        try context.save()

        XCTAssertFalse(FocusStackService.isInFocus(item))
        XCTAssertEqual(item.readState, .filed)
        XCTAssertEqual(item.focusOutcomes.count, 1)
        XCTAssertEqual(item.focusOutcomes.first?.kind, .reference)
    }

    func testCompleteOutcomeTakeawayPinsHighlightNoteOnce() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        let highlight = Highlight(sourceMarkdownOffset: 0, sourceMarkdownLength: 4, quotedText: "note")
        item.highlights = [highlight]
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        try context.save()

        let highlightID = try XCTUnwrap(highlight.id)
        try FocusStackService.completeOutcome(
            item: item,
            kind: .takeaway,
            in: context,
            takeawayText: "Pinned takeaway",
            linkedHighlightID: highlightID
        )
        try context.save()

        XCTAssertEqual(highlight.userNote, "Pinned takeaway")
        XCTAssertEqual(item.focusOutcomes.first?.takeawayText, "Pinned takeaway")
        XCTAssertEqual(item.focusOutcomes.first?.linkedHighlightID, highlightID)
    }

    func testCompleteOutcomeRevisitStoresSchedule() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        try context.save()

        let due = Date(timeIntervalSince1970: 1_800_000_000)
        try FocusStackService.completeOutcome(
            item: item,
            kind: .revisit,
            in: context,
            scheduledResurfaceAt: due
        )
        try context.save()

        XCTAssertEqual(item.focusOutcomes.first?.scheduledResurfaceAt, due)
        XCTAssertFalse(FocusStackService.isInFocus(item))
    }

    func testReleaseForSwapLogsReleaseOnRemovedItemOnly() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let swapped = makeItem(title: "swap")
        let keeper = makeItem(title: "keeper")
        context.insert(swapped)
        context.insert(keeper)
        try FocusStackService.addToFocus(item: swapped, in: context)
        try FocusStackService.addToFocus(item: keeper, in: context)
        try context.save()

        let swappedEntry = try XCTUnwrap(swapped.focusEntry)
        try FocusStackService.releaseForSwap(entry: swappedEntry, in: context)
        try context.save()

        XCTAssertFalse(FocusStackService.isInFocus(swapped))
        XCTAssertTrue(FocusStackService.isInFocus(keeper))
        XCTAssertEqual(swapped.focusOutcomes.count, 1)
        XCTAssertEqual(swapped.focusOutcomes.first?.kind, .release)
        XCTAssertTrue(keeper.focusOutcomes.isEmpty)
    }

    func testReAddAfterRemoveResetsMembershipClock() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)

        let firstAdd = Date(timeIntervalSince1970: 1_700_000_000)
        try FocusStackService.addToFocus(item: item, in: context, now: firstAdd)
        try context.save()
        let firstEntryID = try XCTUnwrap(item.focusEntry?.id)

        try FocusStackService.removeFromFocus(item: item, in: context)
        try context.save()

        let secondAdd = Date(timeIntervalSince1970: 1_710_000_000)
        try FocusStackService.addToFocus(item: item, in: context, now: secondAdd)
        try context.save()

        XCTAssertNotEqual(item.focusEntry?.id, firstEntryID)
        XCTAssertEqual(item.focusEntry?.addedAt, secondAdd)
        XCTAssertEqual(item.focusEntry?.lastTouchedAt, secondAdd)
    }

    func testTouchEngagementUpdatesLastTouchedAt() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        let addedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try FocusStackService.addToFocus(item: item, in: context, now: addedAt)
        try context.save()

        let touchedAt = Date(timeIntervalSince1970: 1_705_000_000)
        FocusStackService.touchEngagement(item: item, in: context, now: touchedAt)
        try context.save()

        XCTAssertEqual(item.focusEntry?.lastTouchedAt, touchedAt)
    }

    func testTouchEngagementNoOpWhenNotInFocus() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try context.save()

        FocusStackService.touchEngagement(item: item, in: context, now: .now)
        XCTAssertNil(item.focusEntry)
    }

    func testDueForRevisitWhenPastDueAndNotInFocus() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)

        let past = Date(timeIntervalSince1970: 1_000_000_000)
        let outcome = FocusOutcome(
            contentItem: item,
            kind: .revisit,
            completedAt: past,
            scheduledResurfaceAt: Date(timeIntervalSince1970: 1_100_000_000)
        )
        context.insert(outcome)
        item.focusOutcomes = [outcome]
        try context.save()

        XCTAssertTrue(FocusStackService.dueForRevisit(item, in: context, now: .now))
    }

    func testDueForRevisitFalseWhenStillInFocus() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        let outcome = FocusOutcome(
            contentItem: item,
            kind: .revisit,
            scheduledResurfaceAt: Date(timeIntervalSince1970: 1)
        )
        context.insert(outcome)
        item.focusOutcomes.append(outcome)
        try context.save()

        XCTAssertFalse(FocusStackService.dueForRevisit(item, in: context, now: .now))
    }

    func testReorderRewritesContiguousSortOrder() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        var entries: [FocusEntry] = []
        for index in 0 ..< 3 {
            let item = makeItem(title: "row-\(index)")
            context.insert(item)
            let entry = FocusEntry(contentItem: item, sortOrder: index)
            context.insert(entry)
            item.focusEntry = entry
            entries.append(entry)
        }
        try context.save()

        FocusStackService.reorder(entries: entries, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        try context.save()

        let sorted = entries.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(sorted.map(\.sortOrder), [0, 1, 2])
        XCTAssertEqual(sorted.map { $0.contentItem?.title }, ["row-2", "row-0", "row-1"])
    }

    func testDropFocusEntryOnArchiveClearsMembership() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = makeItem()
        context.insert(item)
        try FocusStackService.addToFocus(item: item, in: context)
        try context.save()

        FocusStackService.dropFocusEntryOnArchive(item: item, in: context)
        try context.save()

        XCTAssertFalse(FocusStackService.isInFocus(item))
        XCTAssertTrue(item.focusOutcomes.isEmpty)
    }

    func testActiveEntriesExcludeArchivedItems() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let active = makeItem(title: "active")
        let archived = makeItem(title: "archived")
        archived.isArchived = true
        context.insert(active)
        context.insert(archived)
        try FocusStackService.addToFocus(item: active, in: context)
        let staleArchivedEntry = FocusEntry(contentItem: archived, sortOrder: 1)
        context.insert(staleArchivedEntry)
        archived.focusEntry = staleArchivedEntry
        try context.save()

        let activeEntries = try FocusStackService.activeEntries(in: context)
        XCTAssertEqual(activeEntries.count, 1)
        XCTAssertEqual(activeEntries.first?.contentItem?.title, "active")
    }

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = PhathomModelContainer.currentSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeItem(title: String = "item") -> ContentItem {
        let item = ContentItem(contentKind: .web, originalURL: URL(string: "https://example.com/\(title)")!)
        item.title = title
        item.titleUserSet = true
        return item
    }
}
