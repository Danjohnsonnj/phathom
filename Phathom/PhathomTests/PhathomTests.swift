//
//  PhathomTests.swift
//  PhathomTests
//
//  Created by Daniel Johnson on 4/29/26.
//

import Foundation
import Network
import PhathomCore
import SwiftData
import Testing
import UIKit
@testable import Phathom
@testable import PhathomInference

private actor OrderLog {
    private(set) var values: [Int] = []
    func append(_ v: Int) { values.append(v) }
}

/// Keys must stay aligned with `ModelManager` for save/restore around `clearSelection()` / `clearTaggingSelection()` / `clearVisionSelection()`.
private enum TestModelUserDefaultsKeys {
    static let bookmark = "phathom.selectedGGUFBookmark"
    static let taggingBookmark = "phathom.selectedGGUFBookmark.tagging"
    static let visionTextBookmark = "phathom.selectedGGUFBookmark.vision.text"
    static let visionMmprojBookmark = "phathom.selectedGGUFBookmark.vision.mmproj"
    static let legacyPath = "phathom.selectedGGUFPath"
}

/// Parallel suites mutate vision bookmarks; serialize those tests across the module.
private let visionSelectionTestGate = DispatchQueue(label: "phathom.tests.vision-selection")

private func restoreVisionBookmarks(text savedText: Data?, mmproj savedMmproj: Data?) {
    let defaults = UserDefaults.standard
    if let savedText {
        defaults.set(savedText, forKey: TestModelUserDefaultsKeys.visionTextBookmark)
    } else {
        defaults.removeObject(forKey: TestModelUserDefaultsKeys.visionTextBookmark)
    }
    if let savedMmproj {
        defaults.set(savedMmproj, forKey: TestModelUserDefaultsKeys.visionMmprojBookmark)
    } else {
        defaults.removeObject(forKey: TestModelUserDefaultsKeys.visionMmprojBookmark)
    }
}

private func withSavedVisionBookmarks<T>(_ body: () throws -> T) rethrows -> T {
    try visionSelectionTestGate.sync {
        let defaults = UserDefaults.standard
        let savedText = defaults.data(forKey: TestModelUserDefaultsKeys.visionTextBookmark)
        let savedMmproj = defaults.data(forKey: TestModelUserDefaultsKeys.visionMmprojBookmark)
        defer { restoreVisionBookmarks(text: savedText, mmproj: savedMmproj) }
        return try body()
    }
}

private func withSavedVisionBookmarks<T>(_ body: @escaping () async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        visionSelectionTestGate.async {
            let defaults = UserDefaults.standard
            let savedText = defaults.data(forKey: TestModelUserDefaultsKeys.visionTextBookmark)
            let savedMmproj = defaults.data(forKey: TestModelUserDefaultsKeys.visionMmprojBookmark)
            Task {
                do {
                    let result = try await body()
                    restoreVisionBookmarks(text: savedText, mmproj: savedMmproj)
                    continuation.resume(returning: result)
                } catch {
                    restoreVisionBookmarks(text: savedText, mmproj: savedMmproj)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct PhathomTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    /// Second acquire waits until the first holder calls `release` (FIFO lock).
    @Test func asyncLockSerializesWaiters() async throws {
        let lock = AsyncLock()
        let log = OrderLog()
        await lock.acquire()
        let second = Task {
            await lock.acquire()
            await log.append(2)
            await lock.release()
        }
        try await Task.sleep(for: .milliseconds(50))
        await log.append(1)
        await lock.release()
        _ = await second.value
        let order = await log.values
        #expect(order == [1, 2])
    }

    /// `withLock` releases after thrown errors so a follow-up acquire succeeds.
    @Test func asyncLockWithLockReleasesOnThrow() async throws {
        let lock = AsyncLock()
        enum E: Error { case boom }
        await #expect(throws: E.self) {
            try await lock.withLock {
                throw E.boom
            }
        }
        await lock.acquire()
        await lock.release()
    }

    /// Same FIFO behavior as `AsyncLock`, via `SharedLlamaInference`'s lifecycle mutex (no GGUF load).
    @Test func sharedInferenceExclusiveLockSerializesWaiters() async throws {
        let log = OrderLog()
        await SharedLlamaInference.shared._test_withExclusiveLifecycleLock {
            await log.append(1)
        }
        await SharedLlamaInference.shared._test_withExclusiveLifecycleLock {
            await log.append(2)
        }
        let order = await log.values
        #expect(order == [1, 2])
    }

    /// A second `_test_withExclusiveLifecycleLock` does not run until the first releases the shared lifecycle mutex.
    @Test func sharedInferenceExclusiveLockBlocksConcurrentAcquire() async throws {
        let log = OrderLog()
        let first = Task {
            try await SharedLlamaInference.shared._test_withExclusiveLifecycleLock {
                try await Task.sleep(for: .milliseconds(50))
                await log.append(1)
            }
        }
        try await Task.sleep(for: .milliseconds(10))
        let second = Task {
            try await SharedLlamaInference.shared._test_withExclusiveLifecycleLock {
                await log.append(2)
            }
        }
        _ = try await first.value
        _ = try await second.value
        let order = await log.values
        #expect(order == [1, 2])
    }

    @Test func pendingWebStepSkipsMalformedOldestAndProcessesNextValid() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let malformed = ContentItem(
            createdAt: Date(timeIntervalSince1970: 10),
            contentKind: .web,
            originalURL: nil
        )
        malformed.processingStatus = ProcessingStatus.pending.rawValue
        malformed.processingDetail = "Queued for capture"
        let valid = ContentItem(
            createdAt: Date(timeIntervalSince1970: 20),
            contentKind: .web,
            originalURL: URL(string: "https://example.com")!
        )
        valid.processingStatus = ProcessingStatus.pending.rawValue
        valid.processingDetail = "Queued for capture"
        ctx.insert(malformed)
        ctx.insert(valid)
        try ctx.save()
        let malformedID = malformed.id
        let validID = valid.id

        let didWork = await BackgroundPipeline._test_processNextPendingWebItem(modelContainer: container)
        #expect(didWork)

        let fdBad = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == malformedID })
        let fdGood = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == validID })
        let badFresh = try #require(ctx.fetch(fdBad).first)
        let goodFresh = try #require(ctx.fetch(fdGood).first)
        #expect(badFresh.status == .failed)
        #expect(badFresh.failureReason == "Capture payload missing URL.")
        #expect(goodFresh.status != .pending)
    }

    @Test func pendingWebStepReturnsFalseWhenQueueHeadOffline() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let one = ContentItem(
            createdAt: Date(timeIntervalSince1970: 10),
            contentKind: .web,
            originalURL: URL(string: "https://example.com/one")!
        )
        one.processingStatus = ProcessingStatus.pending.rawValue
        one.processingDetail = "Queued for capture"
        let two = ContentItem(
            createdAt: Date(timeIntervalSince1970: 20),
            contentKind: .web,
            originalURL: URL(string: "https://example.com/two")!
        )
        two.processingStatus = ProcessingStatus.pending.rawValue
        two.processingDetail = "Queued for capture"
        ctx.insert(one)
        ctx.insert(two)
        try ctx.save()
        let oneID = one.id
        let twoID = two.id

        let oldStatus = NetworkReachability._test_forceStatus(.requiresConnection)
        defer { _ = NetworkReachability._test_forceStatus(oldStatus) }
        let didWork = await BackgroundPipeline._test_processNextPendingWebItem(modelContainer: container)
        #expect(!didWork)

        let fdOne = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == oneID })
        let fdTwo = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == twoID })
        let oneFresh = try #require(ctx.fetch(fdOne).first)
        let twoFresh = try #require(ctx.fetch(fdTwo).first)
        #expect(oneFresh.status == .pending)
        #expect(twoFresh.status == .pending)
    }

    @Test func pauseProcessingForArchive_nonTerminalClearsAIDerivedAndSetsIdleFailed() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let t = Tag(name: "topic-a")
        ctx.insert(t)
        let item = ContentItem(contentKind: .web, originalURL: URL(string: "https://archive-pause.test/x")!)
        item.processingStatus = ProcessingStatus.embedding.rawValue
        item.processingDetail = ProcessingStatusCopy.embeddingProcessingDetail
        item.summaryBullets = "[]"
        item.tags.append(t)
        ctx.insert(item)
        try ctx.save()

        await MainActor.run {
            ArchiveRetention.pauseProcessingForArchive(item)
        }
        #expect(item.status == .failed)
        #expect(item.summaryBullets == nil)
        #expect(item.extracts == nil)
        #expect(item.tags.isEmpty)
        #expect(item.processingDetail == nil)
        #expect(item.failureReason == nil)
    }

    @Test func pauseProcessingForArchive_terminalCompletedOnlyClearsProcessingDetail() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let item = ContentItem(contentKind: .web, originalURL: URL(string: "https://archive-pause.test/y")!)
        item.processingStatus = ProcessingStatus.completed.rawValue
        item.processingDetail = "Regenerating tags…"
        ctx.insert(item)
        try ctx.save()

        await MainActor.run {
            ArchiveRetention.pauseProcessingForArchive(item)
        }
        #expect(item.status == .completed)
        #expect(item.processingDetail == nil)
    }

    @Test func archivedFailedItemExcludedFromEmbeddingQueueAndRefetchesAsArchived() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let item = ContentItem(contentKind: .web, originalURL: URL(string: "https://archive-queue.test/z")!)
        item.processingStatus = ProcessingStatus.embedding.rawValue
        ctx.insert(item)
        try ctx.save()
        let id = item.id

        await MainActor.run {
            ArchiveRetention.pauseProcessingForArchive(item)
            ArchiveRetention.archive(item, in: ctx)
        }
        try ctx.save()

        var desc = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { row in
                !row.isArchived && row.processingStatus == "embedding"
            }
        )
        #expect((try ctx.fetch(desc)).isEmpty)
        #expect(BackgroundPipeline._test_isItemArchived(itemID: id, modelContainer: container))
    }

    /// Empty search query: `bucket` applies kind/status filters without requiring tag-index / adjacent work.
    @Test func librarySearchBucket_emptyQuery_appliesKindAndStatusFilters() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let webNew = ContentItem(contentKind: .web, originalURL: URL(string: "https://a.test")!)
        webNew.readStatus = ReadStatus.new.rawValue
        webNew.title = "Alpha"
        let webRead = ContentItem(contentKind: .web, originalURL: URL(string: "https://b.test")!)
        webRead.readStatus = ReadStatus.read.rawValue
        webRead.title = "Bravo"
        let note = ContentItem(contentKind: .note)
        note.readStatus = ReadStatus.new.rawValue
        note.rawText = "hello"
        note.title = "Note"
        ctx.insert(webNew)
        ctx.insert(webRead)
        ctx.insert(note)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let browseAll = LibrarySearchService.bucket(query: "", items: all)
        #expect(browseAll.matching.count == 3)
        #expect(browseAll.adjacent.isEmpty)
        #expect(browseAll.resolvedTagName == nil)

        let webReadOnly = LibrarySearchService.bucket(
            query: "",
            items: all,
            filterKinds: [.web],
            filterStatuses: [.read]
        )
        #expect(webReadOnly.matching.count == 1)
        #expect(webReadOnly.matching.first?.id == webRead.id)

        let textSearch = LibrarySearchService.bucket(query: "hello", items: all)
        #expect(textSearch.matching.contains(where: { $0.id == note.id }))
    }

    @Test func libraryFilterCodec_migrationAndCapsuleLabels() {
        #expect(LibraryFilterCodec.decodeKinds("") == nil)
        #expect(LibraryFilterCodec.decodeKinds("web") == Set([.web]))
        #expect(LibraryFilterCodec.decodeKinds("bogus,web") == Set([.web]))
        #expect(LibraryFilterCodec.decodeStatuses("") == nil)
        #expect(LibraryFilterCodec.decodeStatuses("read") == Set([.read]))
        #expect(LibraryFilterCodec.decodeStatuses("bogus,read") == Set([.read]))

        #expect(LibraryFilterCodec.kindCapsuleLabel(raw: "") == "All")
        #expect(LibraryFilterCodec.kindCapsuleLabel(raw: "web") == "Web")
        #expect(LibraryFilterCodec.kindCapsuleLabel(raw: "web,note") == "Web +1")
        #expect(LibraryFilterCodec.statusCapsuleLabel(raw: "new,read") == "New +1")

        let fullKinds = LibraryFilterCodec.encodeKinds([.web, .media, .note])
        #expect(fullKinds == "")
        let fullStatuses = LibraryFilterCodec.encodeStatuses([.new, .read, .filed])
        #expect(fullStatuses == "")

        let valid = ["work", "travel", "home"]
        let sorted = valid.sorted()

        #expect(LibraryFilterCodec.categoryCapsuleLabel(raw: "", sortedCategoryNames: sorted) == "All")
        #expect(LibraryFilterCodec.categoryCapsuleLabel(raw: "work", sortedCategoryNames: sorted) == "Work")
        #expect(
            LibraryFilterCodec.categoryCapsuleLabel(
                raw: "\(LibraryCategoryFilterStorage.uncategorizedRaw),work",
                sortedCategoryNames: sorted
            ) == "Work +1"
        )
        #expect(
            LibraryFilterCodec.categoryCapsuleLabel(
                raw: "\(LibraryCategoryFilterStorage.uncategorizedRaw),work,travel",
                sortedCategoryNames: sorted
            ) == "Work +2"
        )
        #expect(
            LibraryFilterCodec.categoryCapsuleLabel(raw: "home,work", sortedCategoryNames: sorted) == "Home +1"
        )
        #expect(
            LibraryFilterCodec.categoryAccessibilityValue(
                raw: "\(LibraryCategoryFilterStorage.uncategorizedRaw),work,travel",
                sortedCategoryNames: sorted
            ) == "Uncategorized, Travel, Work"
        )
    }

    @Test func libraryFilterCodec_categoryCapsuleLabelParts() {
        let sorted = ["home", "travel", "work"]
        let screenshotSorted = ["jersey-city", "tech", "xylophonicalised"]

        func expectParts(
            raw: String,
            sortedCategoryNames: [String],
            lead: String,
            plusN: Int?
        ) {
            let parts = LibraryFilterCodec.categoryCapsuleLabelParts(
                raw: raw,
                sortedCategoryNames: sortedCategoryNames
            )
            #expect(parts.lead == lead)
            #expect(parts.plusN == plusN)
            let composed = parts.plusN.map { "\(parts.lead) +\($0)" } ?? parts.lead
            #expect(LibraryFilterCodec.categoryCapsuleLabel(raw: raw, sortedCategoryNames: sortedCategoryNames) == composed)
        }

        expectParts(raw: "", sortedCategoryNames: sorted, lead: "All", plusN: nil)
        expectParts(raw: "work", sortedCategoryNames: sorted, lead: "Work", plusN: nil)
        expectParts(
            raw: "\(LibraryCategoryFilterStorage.uncategorizedRaw),work",
            sortedCategoryNames: sorted,
            lead: "Work",
            plusN: 1
        )
        expectParts(
            raw: "\(LibraryCategoryFilterStorage.uncategorizedRaw),work,travel",
            sortedCategoryNames: sorted,
            lead: "Work",
            plusN: 2
        )
        expectParts(raw: "home,work", sortedCategoryNames: sorted, lead: "Home", plusN: 1)
        expectParts(
            raw: "\(LibraryCategoryFilterStorage.uncategorizedRaw),xylophonicalised",
            sortedCategoryNames: screenshotSorted,
            lead: "Uncategorized",
            plusN: 1
        )
    }

    @Test func libraryFilterCodec_categorySanitizeAndToggle() {
        let valid = ["work", "travel"]
        #expect(LibraryFilterCodec.sanitizeCategoryRaw("work,deleted", validNames: valid) == "work")
        #expect(LibraryFilterCodec.sanitizeCategoryRaw("deleted", validNames: valid) == "")

        let universe = LibraryFilterCodec.categoryUniverse(categoryNames: valid)
        #expect(LibraryFilterCodec.toggleCategory("work", in: "work", universe: universe) == nil)
        let widened = LibraryFilterCodec.toggleCategory("travel", in: "work", universe: universe)
        #expect(widened == "travel,work")
        let full = LibraryFilterCodec.toggleCategory(LibraryCategoryFilterStorage.uncategorizedRaw, in: "travel,work", universe: universe)
        #expect(full == "")
    }

    @Test func itemsFilteredByKindStatusAndCategory_orWithinAndAcross() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)

        let webNew = ContentItem(contentKind: .web, originalURL: URL(string: "https://or.test/a")!)
        webNew.readStatus = ReadStatus.new.rawValue
        let webRead = ContentItem(contentKind: .web, originalURL: URL(string: "https://or.test/b")!)
        webRead.readStatus = ReadStatus.read.rawValue
        let noteFiled = ContentItem(contentKind: .note)
        noteFiled.readStatus = ReadStatus.filed.rawValue

        let work = PhathomCore.Category(name: "work")
        ctx.insert(work)
        webNew.category = work

        ctx.insert(webNew)
        ctx.insert(webRead)
        ctx.insert(noteFiled)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())

        let newOrRead = TagRelationService.itemsFilteredByKindStatusAndCategory(
            items: all,
            filterStatuses: [.new, .read]
        )
        #expect(newOrRead.count == 2)
        #expect(newOrRead.contains(where: { $0.id == webNew.id }))
        #expect(newOrRead.contains(where: { $0.id == webRead.id }))

        let webAndNew = TagRelationService.itemsFilteredByKindStatusAndCategory(
            items: all,
            filterKinds: [.web],
            filterStatuses: [.new]
        )
        #expect(webAndNew.count == 1)
        #expect(webAndNew.first?.id == webNew.id)

        let uncategorizedOnly = TagRelationService.itemsFilteredByKindStatusAndCategory(
            items: all,
            filterCategories: [LibraryCategoryFilterStorage.uncategorizedRaw]
        )
        #expect(uncategorizedOnly.count == 2)
        #expect(!uncategorizedOnly.contains(where: { $0.id == webNew.id }))
    }

    @Test func librarySearchBucket_multiselectOrWithinStatus() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let webNew = ContentItem(contentKind: .web, originalURL: URL(string: "https://ms.test/a")!)
        webNew.readStatus = ReadStatus.new.rawValue
        let webRead = ContentItem(contentKind: .web, originalURL: URL(string: "https://ms.test/b")!)
        webRead.readStatus = ReadStatus.read.rawValue
        let noteFiled = ContentItem(contentKind: .note)
        noteFiled.readStatus = ReadStatus.filed.rawValue
        ctx.insert(webNew)
        ctx.insert(webRead)
        ctx.insert(noteFiled)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let newOrRead = LibrarySearchService.bucket(
            query: "",
            items: all,
            filterStatuses: [.new, .read]
        )
        #expect(newOrRead.matching.count == 2)
    }

    @Test func librarySearch_matchesHighlightUserNoteOnly() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let probe = "xyzzyplugh"

        let withNote = ContentItem(contentKind: .web, originalURL: URL(string: "https://highlight-note-search.test/with")!)
        withNote.title = "Article"
        let withNoteHighlight = Highlight(
            sourceMarkdownOffset: 0,
            sourceMarkdownLength: 10,
            quotedText: "some quote",
            userNote: probe
        )
        ctx.insert(withNote)
        ctx.insert(withNoteHighlight)
        withNote.highlights.append(withNoteHighlight)

        let withoutNote = ContentItem(contentKind: .web, originalURL: URL(string: "https://highlight-note-search.test/without")!)
        withoutNote.title = "Other"
        let withoutNoteHighlight = Highlight(
            sourceMarkdownOffset: 0,
            sourceMarkdownLength: 10,
            quotedText: "other quote"
        )
        ctx.insert(withoutNote)
        ctx.insert(withoutNoteHighlight)
        withoutNote.highlights.append(withoutNoteHighlight)

        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let sections = LibrarySearchService.bucket(query: probe, items: all)
        #expect(sections.matching.contains(where: { $0.id == withNote.id }))
        #expect(!sections.matching.contains(where: { $0.id == withoutNote.id }))
        #expect(sections.adjacent.isEmpty)
        #expect(sections.resolvedTagName == nil)
    }

    @Test func notebookHighlightsQuery_groups_appliesKindAndStatusFilters() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let web = ContentItem(contentKind: .web, originalURL: URL(string: "https://notebook-filter.test/web")!)
        web.readStatus = ReadStatus.read.rawValue
        let note = ContentItem(contentKind: .note)
        note.readStatus = ReadStatus.new.rawValue
        note.rawText = "note body"
        ctx.insert(web)
        ctx.insert(note)

        let webHighlight = Highlight(sourceMarkdownOffset: 0, sourceMarkdownLength: 4, quotedText: "web quote")
        let noteHighlight = Highlight(sourceMarkdownOffset: 0, sourceMarkdownLength: 4, quotedText: "note quote")
        ctx.insert(webHighlight)
        ctx.insert(noteHighlight)
        web.highlights.append(webHighlight)
        note.highlights.append(noteHighlight)
        try ctx.save()

        let allHighlights = try ctx.fetch(FetchDescriptor<Highlight>())
        let unfiltered = NotebookHighlightsQuery.groups(from: allHighlights)
        #expect(unfiltered.count == 2)

        let webOnly = NotebookHighlightsQuery.groups(from: allHighlights, filterKinds: [.web])
        #expect(webOnly.count == 1)
        #expect(webOnly.first?.item.id == web.id)

        let readOnly = NotebookHighlightsQuery.groups(from: allHighlights, filterStatuses: [.read])
        #expect(readOnly.count == 1)
        #expect(readOnly.first?.item.id == web.id)
    }

    @Test func notebookHighlightsQuery_groups_excludesArchivedParent() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let item = ContentItem(contentKind: .web, originalURL: URL(string: "https://notebook-archive.test/x")!)
        ctx.insert(item)
        let highlight = Highlight(sourceMarkdownOffset: 0, sourceMarkdownLength: 3, quotedText: "abc")
        ctx.insert(highlight)
        item.highlights.append(highlight)
        try ctx.save()

        var allHighlights = try ctx.fetch(FetchDescriptor<Highlight>())
        #expect(NotebookHighlightsQuery.groups(from: allHighlights).count == 1)

        item.isArchived = true
        try ctx.save()
        allHighlights = try ctx.fetch(FetchDescriptor<Highlight>())
        #expect(NotebookHighlightsQuery.groups(from: allHighlights).isEmpty)
        #expect(NotebookHighlightsQuery.qualifyingHighlights(from: allHighlights).isEmpty)
    }

    @Test @MainActor
    func tagRelation_exactMatchesOtherThanSource_excludesOriginal() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let rust = Tag(name: "rust")
        ctx.insert(rust)
        let source = ContentItem(contentKind: .web, originalURL: URL(string: "https://exact-source.test")!)
        source.tags.append(rust)
        let other = ContentItem(contentKind: .web, originalURL: URL(string: "https://exact-other.test")!)
        other.tags.append(rust)
        ctx.insert(source)
        ctx.insert(other)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let hits = TagRelationService.exactMatchesOtherThanSource(
            tappedTagName: "rust",
            in: all,
            excludingSourceID: source.id
        )
        #expect(hits.count == 1)
        #expect(hits.first?.id == other.id)
    }

    @Test func tagRelation_prefixResolvedTags_includesHyphenMatch() {
        let vocab = ["rust", "rust-book", "javascript"]
        let set = TagRelationService.prefixResolvedTags(query: "rust", vocabulary: vocab, seedTag: "rust")
        #expect(set.contains("rust"))
        #expect(set.contains("rust-book"))
        #expect(!set.contains("javascript"))
    }

    @Test @MainActor
    func relatedBuckets_adjacent_excludesExactCarriersAndResolvedTag() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let rust = Tag(name: "rust")
        let algo = Tag(name: "algorithms")
        ctx.insert(rust)
        ctx.insert(algo)
        let source = ContentItem(contentKind: .web, originalURL: URL(string: "https://rel-source.test")!)
        source.tags.append(rust)
        source.tags.append(algo)
        let exactSibling = ContentItem(contentKind: .web, originalURL: URL(string: "https://rel-exact.test")!)
        exactSibling.tags.append(rust)
        let related = ContentItem(contentKind: .web, originalURL: URL(string: "https://rel-adj.test")!)
        related.tags.append(algo)
        ctx.insert(source)
        ctx.insert(exactSibling)
        ctx.insert(related)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let buckets = RelatedItemsService.bucketsForTagTap(
            sourceItem: source,
            tappedTag: rust,
            in: all
        )
        #expect(buckets.exactMatches.count == 1)
        #expect(buckets.exactMatches.first?.id == exactSibling.id)
        #expect(buckets.adjacentCandidates.contains(where: { $0.id == related.id }))
        #expect(!buckets.adjacentCandidates.contains(where: { $0.id == exactSibling.id }))
    }

    @Test @MainActor
    func relatedBuckets_manyExactMatches_stillSurfacesAdjacent() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let rust = Tag(name: "rust")
        let algo = Tag(name: "algorithms")
        ctx.insert(rust)
        ctx.insert(algo)
        let source = ContentItem(contentKind: .web, originalURL: URL(string: "https://many-src.test")!)
        source.tags.append(rust)
        source.tags.append(algo)
        for i in 0..<10 {
            let e = ContentItem(contentKind: .web, originalURL: URL(string: "https://many-exact-\(i).test")!)
            e.tags.append(rust)
            ctx.insert(e)
        }
        let related = ContentItem(contentKind: .web, originalURL: URL(string: "https://many-adj.test")!)
        related.tags.append(algo)
        ctx.insert(source)
        ctx.insert(related)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let buckets = RelatedItemsService.bucketsForTagTap(
            sourceItem: source,
            tappedTag: rust,
            in: all
        )
        #expect(buckets.exactMatches.count == 10)
        #expect(buckets.adjacentCandidates.contains(where: { $0.id == related.id }))
    }

    @Test @MainActor
    func relatedRankExpansion_withoutModel_returnsStage1Order() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)

        let defaults = UserDefaults.standard
        let savedBookmark = defaults.data(forKey: TestModelUserDefaultsKeys.bookmark)
        let savedLegacy = defaults.string(forKey: TestModelUserDefaultsKeys.legacyPath)
        defer {
            if let savedBookmark {
                defaults.set(savedBookmark, forKey: TestModelUserDefaultsKeys.bookmark)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.bookmark)
            }
            if let savedLegacy {
                defaults.set(savedLegacy, forKey: TestModelUserDefaultsKeys.legacyPath)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.legacyPath)
            }
        }
        defaults.removeObject(forKey: TestModelUserDefaultsKeys.bookmark)
        defaults.removeObject(forKey: TestModelUserDefaultsKeys.legacyPath)
        ModelManager.clearSelection()

        let rust = Tag(name: "rust")
        let algo = Tag(name: "algorithms")
        ctx.insert(rust)
        ctx.insert(algo)
        let source = ContentItem(contentKind: .web, originalURL: URL(string: "https://rank-src.test")!)
        source.tags.append(rust)
        source.tags.append(algo)
        let related = ContentItem(contentKind: .web, originalURL: URL(string: "https://rank-adj.test")!)
        related.tags.append(algo)
        ctx.insert(source)
        ctx.insert(related)
        try ctx.save()

        #expect(!ModelManager.hasReadableSelection)

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let buckets = RelatedItemsService.bucketsForTagTap(
            sourceItem: source,
            tappedTag: rust,
            in: all
        )
        let out = await RelatedItemsService.rankedAdjacentAfterExpansion(
            sourceItem: source,
            tappedTag: rust,
            in: all,
            exactMatchIDs: Set(buckets.exactMatches.map(\.id)),
            stage1Adjacent: buckets.adjacentCandidates
        )
        #expect(out.map(\.id) == buckets.adjacentCandidates.map(\.id))
    }

    @Test func bulkApplyReadStatus_updatesAllSelected() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let a = ContentItem(contentKind: .web, originalURL: URL(string: "https://bulk-a.test")!)
        a.readStatus = ReadStatus.new.rawValue
        let b = ContentItem(contentKind: .web, originalURL: URL(string: "https://bulk-b.test")!)
        b.readStatus = ReadStatus.new.rawValue
        ctx.insert(a)
        ctx.insert(b)
        try ctx.save()
        let aID = a.id
        let bID = b.id
        ContentItem.applyReadStatus(.filed, to: [a, b], modelContext: ctx)
        let fa = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == aID })
        let fb = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == bID })
        #expect(try ctx.fetch(fa).first?.readState == .filed)
        #expect(try ctx.fetch(fb).first?.readState == .filed)
    }

    @Test func visionProfileResolver_detectsSmolAsCompact() {
        let profile = VisionProfileResolver.autoDetectedProfile(
            textGGUFPath: "/tmp/SmolVLM-500M-Instruct-Q8_0.gguf",
            fileSizeBytes: 900_000_000
        )
        #expect(profile == .compact)
    }

    @Test func visionProfileResolver_detectsQwenVLAsCapable() {
        let profile = VisionProfileResolver.autoDetectedProfile(
            textGGUFPath: "/tmp/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf",
            fileSizeBytes: 2_000_000_000
        )
        #expect(profile == .capable)
    }

    @Test func clearTaggingSelectionRemovesOptionalBookmarkData() {
        let defaults = UserDefaults.standard
        let key = TestModelUserDefaultsKeys.taggingBookmark
        let saved = defaults.data(forKey: key)
        defer {
            if let saved {
                defaults.set(saved, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(Data([0xAB]), forKey: key)
        #expect(ModelManager.hasTaggingBookmark)
        ModelManager.clearTaggingSelection()
        #expect(!ModelManager.hasTaggingBookmark)
    }

    @Test func shareCaptureInsertMediaItemQueuesEmbedding() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try ShareCapture.insertMediaItem(context: ctx, imageJPEGData: jpeg)
        let rows = try ctx.fetch(FetchDescriptor<ContentItem>())
        let item = try #require(rows.first)
        #expect(item.kind == .media)
        #expect(item.status == .embedding)
        #expect(item.processingDetail == ProcessingStatusCopy.embeddingProcessingDetail)
        #expect(item.mediaDescription == nil)
    }

    @Test func activeWebQueueReset_rewindsSummarizingClearsAIDerived() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let tag = Tag(name: "topic-a")
        ctx.insert(tag)
        let active = ContentItem(contentKind: .web, originalURL: URL(string: "https://reset-queue.test/a")!)
        active.processingStatus = ProcessingStatus.summarizing.rawValue
        active.processingDetail = "Generating summary…"
        active.rawText = "article body text"
        active.summaryBullets = "[\"a\"]"
        active.tags.append(tag)
        ctx.insert(active)
        try ctx.save()
        let id = active.id

        await BackgroundPipeline._test_performActiveWebQueueReset(modelContainer: container)

        let after = ModelContext(container)
        let afterFetch = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == id })
        let rows = try after.fetch(afterFetch)
        let row = try #require(rows.first)
        #expect(row.status == .embedding)
        #expect(row.summaryBullets == nil)
        #expect(row.extracts == nil)
        #expect(row.tags.isEmpty)
        #expect(row.failureReason == nil)
        #expect(row.processingDetail == ProcessingStatusCopy.embeddingProcessingDetail)
        #expect(row.rawText == "article body text")
    }

    @Test func activeWebQueueReset_pendingNoBodyKeepsQueuedDetail() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let pendingOnly = ContentItem(contentKind: .web, originalURL: URL(string: "https://reset-queue.test/b")!)
        pendingOnly.processingStatus = ProcessingStatus.pending.rawValue
        pendingOnly.processingDetail = "Queued for capture"
        pendingOnly.rawText = nil
        ctx.insert(pendingOnly)
        try ctx.save()
        let id = pendingOnly.id

        await BackgroundPipeline._test_performActiveWebQueueReset(modelContainer: container)

        let after = ModelContext(container)
        let afterFetch = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == id })
        let rows = try after.fetch(afterFetch)
        let row = try #require(rows.first)
        #expect(row.status == .pending)
        #expect(row.processingDetail == "Queued for capture")
    }

    @Test func activeQueueReset_doesNotTouchCompletedOrFailed() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let completed = ContentItem(contentKind: .web, originalURL: URL(string: "https://reset-queue.test/c")!)
        completed.processingStatus = ProcessingStatus.completed.rawValue
        completed.summaryBullets = "[\"done\"]"

        let failed = ContentItem(contentKind: .web, originalURL: URL(string: "https://reset-queue.test/d")!)
        failed.processingStatus = ProcessingStatus.failed.rawValue
        failed.failureReason = "x"

        let note = ContentItem(contentKind: .note)
        note.rawText = "note md"
        note.processingStatus = ProcessingStatus.tagging.rawValue
        note.processingDetail = "Auto-tagging…"
        note.summaryBullets = "[\"n\"]"

        let mediaStuck = ContentItem(contentKind: .media, originalURL: nil)
        mediaStuck.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        mediaStuck.processingStatus = ProcessingStatus.summarizing.rawValue
        mediaStuck.mediaDescription = "partial"
        mediaStuck.summaryBullets = "[\"m\"]"

        ctx.insert(completed)
        ctx.insert(failed)
        ctx.insert(note)
        ctx.insert(mediaStuck)
        try ctx.save()
        let noteID = note.id
        let mediaID = mediaStuck.id

        await BackgroundPipeline._test_performActiveQueueReset(modelContainer: container)

        let after = ModelContext(container)
        let all = FetchDescriptor<ContentItem>()
        let rows = try after.fetch(all)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })

        let c = try #require(byID[completed.id])
        #expect(c.status == .completed)
        #expect(c.summaryBullets != nil)

        let f = try #require(byID[failed.id])
        #expect(f.status == .failed)
        #expect(f.failureReason == "x")

        let n = try #require(byID[noteID])
        #expect(n.status == .embedding)
        #expect(n.summaryBullets == nil)
        #expect(n.processingDetail == ProcessingStatusCopy.embeddingProcessingDetail)

        let m = try #require(byID[mediaID])
        #expect(m.status == .embedding)
        #expect(m.mediaDescription == nil)
        #expect(m.summaryBullets == nil)
    }
}

@Suite("Pipeline user pause", .serialized)
struct PipelineUserPauseTests {
    @Test func pipelineUserPause_persistsInUserDefaults() {
        defer { PipelineUserPause._test_clearPause() }
        PipelineUserPause.setPaused(true)
        #expect(PipelineUserPause.isPaused)
        #expect(UserDefaults.standard.bool(forKey: PipelineUserPause.defaultsKey))
        PipelineUserPause.setPaused(false)
        #expect(!PipelineUserPause.isPaused)
    }

    @Test func runForegroundDrain_noOpWhenUserPaused() async throws {
        defer { PipelineUserPause._test_clearPause() }
        PipelineUserPause.setPaused(true)
        let container = try makeInMemoryContainer()
        BackgroundPipeline._test_setModelContainer(container)
        let ctx = ModelContext(container)
        let web = ContentItem(contentKind: .web, originalURL: URL(string: "https://pause-drain.test/a")!)
        web.processingStatus = ProcessingStatus.pending.rawValue
        web.processingDetail = "Queued for capture"
        ctx.insert(web)
        try ctx.save()
        let webID = web.id

        await BackgroundPipeline.runForegroundDrain()

        #expect(!BackgroundPipeline.isForegroundDrainActive)
        let after = ModelContext(container)
        let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == webID })).first)
        #expect(row.status == .pending)
    }

    @Test func backgroundIngest_noOpWhenUserPaused() async throws {
        defer { PipelineUserPause._test_clearPause() }
        PipelineUserPause.setPaused(true)
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let web = ContentItem(contentKind: .web, originalURL: URL(string: "https://pause-bg.test/a")!)
        web.processingStatus = ProcessingStatus.pending.rawValue
        ctx.insert(web)
        try ctx.save()
        let webID = web.id

        await BackgroundPipeline._test_performBackgroundIngest(modelContainer: container)

        let after = ModelContext(container)
        let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == webID })).first)
        #expect(row.status == .pending)
    }

    @Test func pauseAllProcessing_setsUserPausedFlag() async throws {
        defer { PipelineUserPause._test_clearPause() }
        let container = try makeInMemoryContainer()
        BackgroundPipeline._test_setModelContainer(container)
        #expect(!PipelineUserPause.isPaused)
        await BackgroundPipeline.pauseAllProcessing()
        #expect(PipelineUserPause.isPaused)
    }

    @Test func markStoppingBeforeRewind_setsStoppingDetailOnEligibleRows() async throws {
        defer { PipelineUserPause._test_clearPause() }
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let active = ContentItem(contentKind: .web, originalURL: URL(string: "https://pause-stop.test/a")!)
        active.processingStatus = ProcessingStatus.summarizing.rawValue
        active.processingDetail = "Generating summary…"
        active.rawText = "body"
        let completed = ContentItem(contentKind: .web, originalURL: URL(string: "https://pause-stop.test/b")!)
        completed.processingStatus = ProcessingStatus.completed.rawValue
        ctx.insert(active)
        ctx.insert(completed)
        try ctx.save()
        let activeID = active.id

        BackgroundPipeline._test_markActiveQueueItemsStopping(modelContainer: container)

        let after = ModelContext(container)
        let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == activeID })).first)
        #expect(row.processingDetail == ProcessingStatusCopy.pauseStoppingDetail)
    }

    @Test func pauseAllProcessing_marksStoppingThenRewindsToReadyToAnalyze() async throws {
        defer { PipelineUserPause._test_clearPause() }
        let container = try makeInMemoryContainer()
        BackgroundPipeline._test_setModelContainer(container)
        let ctx = ModelContext(container)
        let active = ContentItem(contentKind: .web, originalURL: URL(string: "https://pause-stop.test/c")!)
        active.processingStatus = ProcessingStatus.summarizing.rawValue
        active.processingDetail = "Generating summary…"
        active.rawText = "article body text"
        ctx.insert(active)
        try ctx.save()
        let id = active.id

        await BackgroundPipeline.pauseAllProcessing()

        let after = ModelContext(container)
        let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })).first)
        #expect(row.status == .embedding)
        #expect(row.processingDetail == ProcessingStatusCopy.embeddingProcessingDetail)
        #expect(PipelineUserPause.isPaused)
    }

    @Test @MainActor
    func processingRecovery_noOpWhenUserPaused() throws {
        defer { PipelineUserPause._test_clearPause() }
        PipelineUserPause.setPaused(true)
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let failed = ContentItem(contentKind: .web, originalURL: URL(string: "https://pause-retry.test/a")!)
        failed.processingStatus = ProcessingStatus.failed.rawValue
        failed.failureReason = "x"
        ctx.insert(failed)
        try ctx.save()
        #expect(!ProcessingRecovery.retryFailedItemIfNeeded(failed, modelContext: ctx))
        #expect(failed.status == .failed)
    }
}

@Suite("ProcessingRecovery media analyze again")
struct ProcessingRecoveryMediaTests {
    @Test @MainActor func canSummarizeAgainFalseForMediaWithoutVisionModel() {
        withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()
            let item = ContentItem(contentKind: .media, originalURL: nil)
            item.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
            item.processingStatus = ProcessingStatus.completed.rawValue
            item.mediaDescription = "A sunset over water"
            #expect(!ProcessingRecovery.canSummarizeAgain(item))
        }
    }

    @Test @MainActor func canRetryFailedFalseForMediaWithoutVisionModel() {
        withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()
            let item = ContentItem(contentKind: .media, originalURL: nil)
            item.thumbnailData = Data([0x01])
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = "Vision failed"
            #expect(!ProcessingRecovery.canRetryFailed(item))
        }
    }

    @Test @MainActor func canRetryFailedFalseForMediaWithoutThumbnail() {
        let item = ContentItem(contentKind: .media, originalURL: nil)
        item.processingStatus = ProcessingStatus.failed.rawValue
        item.failureReason = "Vision failed"
        #expect(!ProcessingRecovery.canRetryFailed(item))
    }

    @Test @MainActor func summarizeAgainReturnsFalseForCompletedMediaWithoutVision() throws {
        try withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()
            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let media = ContentItem(contentKind: .media, originalURL: nil)
            media.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
            media.processingStatus = ProcessingStatus.completed.rawValue
            media.mediaDescription = "Caption"
            ctx.insert(media)
            try ctx.save()

            #expect(!ProcessingRecovery.summarizeAgain(media, modelContext: ctx))
            #expect(media.mediaDescription == "Caption")
        }
    }
}

@Suite("ProcessingStatusPresentation media labels")
struct ProcessingStatusPresentationMediaTests {
    @Test func summarizingLabelUsesAnalyzingPhotoForMedia() {
        let label = ProcessingStatusPresentation.label(for: .summarizing, contentKind: .media)
        #expect(label == "Analyzing photo")
    }

    @Test func summarizingLabelUsesGeneratingSummaryForWeb() {
        let label = ProcessingStatusPresentation.label(for: .summarizing, contentKind: .web)
        #expect(label == "Generating summary")
    }

    @Test func embeddingLabelIsReadyToAnalyze() {
        let label = ProcessingStatusPresentation.label(for: .embedding, contentKind: .web)
        #expect(label == ProcessingStatusPresentation.embeddingChipLabel)
        #expect(ProcessingStatusPresentation.embeddingProcessingDetail == ProcessingStatusCopy.embeddingProcessingDetail)
    }

    @Test func chipLabelPrefersProcessingDetail() {
        let label = ProcessingStatusPresentation.chipLabel(
            for: .summarizing,
            contentKind: .web,
            processingDetail: "Generating summary…"
        )
        #expect(label == "Generating summary…")

        let fallback = ProcessingStatusPresentation.chipLabel(
            for: .embedding,
            contentKind: .web,
            processingDetail: nil
        )
        #expect(fallback == ProcessingStatusPresentation.embeddingChipLabel)
    }
}

@Suite("Summary insufficient sentinel")
struct SummaryInsufficientSentinelTests {
    @Test func rejectsSentinelWhenSourceHasEnoughWords() {
        let longSource = String(repeating: "word ", count: 150)
        let bullets = [LlamaContentAnalyzer.summaryInsufficientSentinel]
        let sanitized = LlamaContentAnalyzer.sanitizeSummaryBullets(bullets, sourceText: longSource)
        #expect(sanitized.isEmpty)
    }

    @Test func keepsSentinelWhenSourceIsThin() {
        let thinSource = "short note"
        let bullets = [LlamaContentAnalyzer.summaryInsufficientSentinel]
        let sanitized = LlamaContentAnalyzer.sanitizeSummaryBullets(bullets, sourceText: thinSource)
        #expect(sanitized == bullets)
    }

    @Test func keepsRealBulletsUntouched() {
        let source = String(repeating: "word ", count: 200)
        let bullets = ["Core theme", "Novel insight"]
        #expect(LlamaContentAnalyzer.sanitizeSummaryBullets(bullets, sourceText: source) == bullets)
        #expect(!LlamaContentAnalyzer.isSummaryInsufficientSentinel(bullets))
    }
}

@Suite("VisionContentAnalyzer prompt")
struct VisionContentAnalyzerTests {
    @Test func defaultDescribePromptTargetsKnowledgeLibrary() {
        let prompt = VisionContentAnalyzer.defaultDescribePrompt
        #expect(!prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(prompt.localizedCaseInsensitiveContains("knowledge library"))
        #expect(prompt.localizedCaseInsensitiveContains("2 sentences"))
        #expect(prompt.localizedCaseInsensitiveContains("readable text"))
        #expect(prompt.localizedCaseInsensitiveContains("mood"))
        #expect(prompt.localizedCaseInsensitiveContains("camera"))
        #expect(!prompt.localizedCaseInsensitiveContains("in detail"))
    }
}

@Suite("LibrarySearchService media discovery")
struct LibrarySearchMediaTests {
    @Test func librarySearch_matchesMediaDescription() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let media = ContentItem(contentKind: .media, originalURL: nil)
        media.mediaDescription = "Golden retriever on a beach at sunset"
        media.processingStatus = ProcessingStatus.completed.rawValue
        ctx.insert(media)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let sections = LibrarySearchService.bucket(query: "retriever", items: all)
        #expect(sections.matching.count == 1)
        #expect(sections.matching.first?.id == media.id)
    }

    @Test func librarySearch_matchesMediaTagNames() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let tag = Tag(name: "landscape")
        ctx.insert(tag)
        let media = ContentItem(contentKind: .media, originalURL: nil)
        media.mediaDescription = "Hills"
        media.tags.append(tag)
        media.processingStatus = ProcessingStatus.completed.rawValue
        ctx.insert(media)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<ContentItem>())
        let sections = LibrarySearchService.bucket(query: "landscape", items: all)
        #expect(sections.matching.contains { $0.id == media.id })
    }
}

@Suite("BackgroundPipeline mediaStuck revive", .serialized)
struct BackgroundPipelineMediaStuckTests {
    @Test func reviveAbortedRewindsMediaSummarizingToEmbedding() throws {
        try withSavedVisionBookmarks {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let textURL = tempDir.appendingPathComponent("vision-text.gguf")
            let mmprojURL = tempDir.appendingPathComponent("vision-mmproj.gguf")
            try Data([0x01]).write(to: textURL)
            try Data([0x02]).write(to: mmprojURL)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            ModelManager.clearVisionSelection()
            try ModelManager.setVisionTextSelection(from: textURL)
            try ModelManager.setVisionMmprojSelection(from: mmprojURL)
            #expect(ModelManager.hasReadableVisionSelection)

            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let media = ContentItem(contentKind: .media, originalURL: nil)
            media.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
            media.processingStatus = ProcessingStatus.summarizing.rawValue
            media.processingDetail = "Analyzing photo…"
            ctx.insert(media)
            try ctx.save()
            let id = media.id

            BackgroundPipeline._test_reviveAbortedPipelineItems(modelContainer: container)

            let after = ModelContext(container)
            let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })).first)
            #expect(row.status == .embedding)
            #expect(row.processingDetail == ProcessingStatusCopy.embeddingProcessingDetail)
            #expect(row.failureReason == nil)
        }
    }

    @Test func reviveMediaStuckSummarizingWithoutVisionCompletesWithPlaceholder() throws {
        try withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()

            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let media = ContentItem(contentKind: .media, originalURL: nil)
            media.thumbnailData = Data([0x01])
            media.processingStatus = ProcessingStatus.summarizing.rawValue
            media.processingDetail = "Analyzing photo…"
            ctx.insert(media)
            try ctx.save()
            let id = media.id

            BackgroundPipeline._test_reviveAbortedPipelineItems(modelContainer: container)

            let after = ModelContext(container)
            let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })).first)
            #expect(row.status == .completed)
            #expect(row.mediaDescription == ShareCapture.mediaPlaceholderDescription)
        }
    }

    @Test func reviveMediaStuckWithoutVisionCompletesWithPlaceholder() throws {
        try withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()

            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let media = ContentItem(contentKind: .media, originalURL: nil)
            media.thumbnailData = Data([0x01])
            media.processingStatus = ProcessingStatus.tagging.rawValue
            media.processingDetail = "Auto-tagging…"
            ctx.insert(media)
            try ctx.save()
            let id = media.id

            BackgroundPipeline._test_reviveAbortedPipelineItems(modelContainer: container)

            let after = ModelContext(container)
            let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })).first)
            #expect(row.status == .completed)
            #expect(row.mediaDescription == ShareCapture.mediaPlaceholderDescription)
            #expect(row.processingDetail == nil)
        }
    }

    @Test func reviveMediaStuckTaggingWithoutReadableVisionCompletesWithPlaceholder() throws {
        try withSavedVisionBookmarks {
            let defaults = UserDefaults.standard
            let textKey = TestModelUserDefaultsKeys.visionTextBookmark
            let mmprojKey = TestModelUserDefaultsKeys.visionMmprojBookmark
            defaults.set(Data([0x01]), forKey: textKey)
            defaults.set(Data([0x02]), forKey: mmprojKey)
            #expect(ModelManager.hasVisionBookmark)
            #expect(!ModelManager.hasReadableVisionSelection)

            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let media = ContentItem(contentKind: .media, originalURL: nil)
            media.processingStatus = ProcessingStatus.tagging.rawValue
            media.processingDetail = "Auto-tagging…"
            ctx.insert(media)
            try ctx.save()
            let id = media.id

            BackgroundPipeline._test_reviveAbortedPipelineItems(modelContainer: container)

            let after = ModelContext(container)
            let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })).first)
            #expect(row.status == .completed)
            #expect(row.mediaDescription == ShareCapture.mediaPlaceholderDescription)
        }
    }
}

@Suite("ModelManager + media pipeline bookmarks", .serialized)
struct ModelManagerVisionPipelineBookmarkTests {

    @Test func clearVisionSelectionRemovesBothVisionBookmarkData() {
        withSavedVisionBookmarks {
            let defaults = UserDefaults.standard
            let textKey = TestModelUserDefaultsKeys.visionTextBookmark
            let mmprojKey = TestModelUserDefaultsKeys.visionMmprojBookmark
            defaults.set(Data([0x01]), forKey: textKey)
            defaults.set(Data([0x02]), forKey: mmprojKey)
            #expect(ModelManager.hasVisionBookmark)
            #expect(!ModelManager.hasReadableVisionSelection)
            ModelManager.clearVisionSelection()
            #expect(!ModelManager.hasVisionBookmark)
            #expect(!ModelManager.hasReadableVisionSelection)
        }
    }

    @Test func mediaEmbeddingDegradesWithoutVisionModel() async throws {
        try await withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()

            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let media = ContentItem(contentKind: .media, originalURL: nil)
            media.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
            media.processingStatus = ProcessingStatus.embedding.rawValue
            media.processingDetail = ProcessingStatusCopy.embeddingProcessingDetail
            ctx.insert(media)
            try ctx.save()
            let id = media.id

            let outcome = await BackgroundPipeline._test_processNextEmbeddingItem(modelContainer: container)
            #expect(outcome == .finished(taskSuccess: true))

            let after = ModelContext(container)
            let row = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })).first)
            #expect(row.status == .completed)
            #expect(row.mediaDescription == ShareCapture.mediaPlaceholderDescription)
        }
    }

    @Test func embeddingQueueSkipsWebWithoutPrimaryWhenMediaReady() async throws {
        try await withSavedVisionBookmarks {
            let defaults = UserDefaults.standard
            let savedBookmark = defaults.data(forKey: TestModelUserDefaultsKeys.bookmark)
            let savedLegacy = defaults.string(forKey: TestModelUserDefaultsKeys.legacyPath)
            ModelManager.clearSelection()
            ModelManager.clearVisionSelection()
            defer {
                if let savedBookmark {
                    defaults.set(savedBookmark, forKey: TestModelUserDefaultsKeys.bookmark)
                } else {
                    defaults.removeObject(forKey: TestModelUserDefaultsKeys.bookmark)
                }
                if let savedLegacy {
                    defaults.set(savedLegacy, forKey: TestModelUserDefaultsKeys.legacyPath)
                } else {
                    defaults.removeObject(forKey: TestModelUserDefaultsKeys.legacyPath)
                }
            }

            let container = try makeInMemoryContainer()
            let ctx = ModelContext(container)
            let web = ContentItem(
                createdAt: Date(timeIntervalSince1970: 10),
                contentKind: .web,
                originalURL: URL(string: "https://media-gate.test/a")!
            )
            web.rawText = "article"
            web.processingStatus = ProcessingStatus.embedding.rawValue
            let media = ContentItem(
                createdAt: Date(timeIntervalSince1970: 20),
                contentKind: .media,
                originalURL: nil
            )
            media.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
            media.processingStatus = ProcessingStatus.embedding.rawValue
            ctx.insert(web)
            ctx.insert(media)
            try ctx.save()
            let webID = web.id
            let mediaID = media.id

            _ = await BackgroundPipeline._test_processNextEmbeddingItem(modelContainer: container)

            let after = ModelContext(container)
            let webRow = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == webID })).first)
            let mediaRow = try #require(try after.fetch(FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == mediaID })).first)
            #expect(webRow.status == .embedding)
            #expect(mediaRow.status == .completed)
        }
    }
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = PhathomModelContainer.currentSchema
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

// UserDefaults mutation: run serially so parallel tests do not see a cleared model selection.
@Suite("SharedLlamaInference withSession + selection", .serialized)
struct SharedLlamaInferenceWithSessionTests {

    @Test func withSessionReleasesLockWhenNoModelSelected() async throws {
        let defaults = UserDefaults.standard
        let savedBookmark = defaults.data(forKey: TestModelUserDefaultsKeys.bookmark)
        let savedLegacy = defaults.string(forKey: TestModelUserDefaultsKeys.legacyPath)
        let savedTagging = defaults.data(forKey: TestModelUserDefaultsKeys.taggingBookmark)
        ModelManager.clearSelection()
        ModelManager.clearTaggingSelection()
        defer {
            if let savedBookmark {
                defaults.set(savedBookmark, forKey: TestModelUserDefaultsKeys.bookmark)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.bookmark)
            }
            if let savedLegacy {
                defaults.set(savedLegacy, forKey: TestModelUserDefaultsKeys.legacyPath)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.legacyPath)
            }
            if let savedTagging {
                defaults.set(savedTagging, forKey: TestModelUserDefaultsKeys.taggingBookmark)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.taggingBookmark)
            }
        }

        await #expect(throws: SharedLlamaInferenceError.noModelSelected) {
            try await SharedLlamaInference.shared.withSession { _ in }
        }

        await SharedLlamaInference.shared._test_withExclusiveLifecycleLock { }
    }

    @Test func withSessionWaitsForExclusiveTestLock() async throws {
        let defaults = UserDefaults.standard
        let savedBookmark = defaults.data(forKey: TestModelUserDefaultsKeys.bookmark)
        let savedLegacy = defaults.string(forKey: TestModelUserDefaultsKeys.legacyPath)
        let savedTagging = defaults.data(forKey: TestModelUserDefaultsKeys.taggingBookmark)
        ModelManager.clearSelection()
        ModelManager.clearTaggingSelection()
        defer {
            if let savedBookmark {
                defaults.set(savedBookmark, forKey: TestModelUserDefaultsKeys.bookmark)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.bookmark)
            }
            if let savedLegacy {
                defaults.set(savedLegacy, forKey: TestModelUserDefaultsKeys.legacyPath)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.legacyPath)
            }
            if let savedTagging {
                defaults.set(savedTagging, forKey: TestModelUserDefaultsKeys.taggingBookmark)
            } else {
                defaults.removeObject(forKey: TestModelUserDefaultsKeys.taggingBookmark)
            }
        }

        let log = OrderLog()
        let holder = Task {
            try await SharedLlamaInference.shared._test_withExclusiveLifecycleLock {
                await log.append(1)
                try await Task.sleep(for: .milliseconds(60))
                await log.append(2)
            }
        }

        try await Task.sleep(for: .milliseconds(20))

        let waiter = Task {
            await #expect(throws: SharedLlamaInferenceError.noModelSelected) {
                try await SharedLlamaInference.shared.withSession { _ in }
            }
            await log.append(3)
        }

        _ = try await holder.value
        _ = await waiter.value
        let order = await log.values
        #expect(order == [1, 2, 3])
    }

    @Test func withVisionSessionReleasesLockWhenNoVisionModelSelected() async throws {
        try await withSavedVisionBookmarks {
            ModelManager.clearVisionSelection()

            await #expect(throws: SharedLlamaInferenceError.noVisionModelSelected) {
                try await SharedLlamaInference.shared.withSession(role: .vision) { _ in }
            }

            await SharedLlamaInference.shared._test_withExclusiveLifecycleLock { }
        }
    }
}

@Suite("TypographyScale")
struct TypographyScaleTests {
    @Test func scaledAtNormalMultiplier() {
        let scale = TypographyScale(multiplier: 1.0)
        #expect(scale.scaled(16) == 16)
        #expect(scale.scaled(34) == 34)
    }

    @Test func scaledAtLargeMultiplier() {
        let scale = TypographyScale(multiplier: 1.15)
        #expect(scale.scaled(16) == 18.5)
    }

    @Test func scaledAtSmallestMultiplierFloorsAt11() {
        let scale = TypographyScale(multiplier: 0.80)
        #expect(scale.scaled(12) == 11)
    }

    @Test func scaledRoundsToHalfPoint() {
        let scale = TypographyScale(multiplier: 0.90)
        #expect(scale.scaled(17) == 15.5)
    }

    @Test func preferenceMultipliers() {
        #expect(AppTextSizePreference.xs.multiplier == 0.80)
        #expect(AppTextSizePreference.xl.multiplier == 1.30)
    }
}

#if os(iOS)
@Suite("MediaImageEncoding library storage")
struct MediaImageEncodingLibraryStorageTests {
    @Test func libraryStorageJPEGSmallerThanDefaultNormalization() throws {
        let size = CGSize(width: 2400, height: 1800)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let full = try #require(MediaImageEncoding.normalizedJPEG(from: image))
        let library = try #require(MediaImageEncoding.normalizedJPEGForLibraryStorage(from: image))
        #expect(library.count < full.count)
    }
}

@Suite("MediaDisplayImageLoader coalesce")
struct MediaDisplayImageLoaderCoalesceTests {
    @Test func concurrentLoadsShareSingleThumbnailFetch() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = ContentItem(contentKind: .media, originalURL: nil)
        item.thumbnailData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        context.insert(item)
        try context.save()
        let itemID = item.id

        MediaThumbnailDataFetcher.TestSupport.fetchCount = 0
        MediaThumbnailDataFetcher.TestSupport.artificialDelayNs = 50_000_000
        defer {
            MediaThumbnailDataFetcher.TestSupport.artificialDelayNs = 0
            MediaThumbnailDataFetcher.TestSupport.fetchCount = 0
        }

        async let first = MediaDisplayImageLoader.loadDisplayImage(
            itemID: itemID,
            modelContainer: container
        )
        async let second = MediaDisplayImageLoader.loadDisplayImage(
            itemID: itemID,
            modelContainer: container
        )
        _ = await (first, second)

        #expect(MediaThumbnailDataFetcher.TestSupport.fetchCount == 1)
    }
}
#endif
