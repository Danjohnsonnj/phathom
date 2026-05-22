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
@testable import Phathom

private actor OrderLog {
    private(set) var values: [Int] = []
    func append(_ v: Int) { values.append(v) }
}

/// Keys must stay aligned with `ModelManager` for save/restore around `clearSelection()` / `clearTaggingSelection()`.
private enum TestModelUserDefaultsKeys {
    static let bookmark = "phathom.selectedGGUFBookmark"
    static let taggingBookmark = "phathom.selectedGGUFBookmark.tagging"
    static let legacyPath = "phathom.selectedGGUFPath"
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
        item.processingDetail = "Preparing analysis…"
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
            ArchiveRetention.archive(item)
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
        let browseAll = LibrarySearchService.bucket(query: "", items: all, filterKind: nil, filterStatus: nil, filterCategory: nil)
        #expect(browseAll.matching.count == 3)
        #expect(browseAll.adjacent.isEmpty)
        #expect(browseAll.resolvedTagName == nil)

        let webReadOnly = LibrarySearchService.bucket(query: "", items: all, filterKind: .web, filterStatus: .read, filterCategory: nil)
        #expect(webReadOnly.matching.count == 1)
        #expect(webReadOnly.matching.first?.id == webRead.id)

        let textSearch = LibrarySearchService.bucket(query: "hello", items: all, filterKind: nil, filterStatus: nil, filterCategory: nil)
        #expect(textSearch.matching.contains(where: { $0.id == note.id }))
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
}
