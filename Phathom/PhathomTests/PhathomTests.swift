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

/// Keys must stay aligned with `ModelManager` for save/restore around `clearSelection()`.
private enum TestModelUserDefaultsKeys {
    static let bookmark = "phathom.selectedGGUFBookmark"
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
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([
        ContentItem.self,
        PhathomCore.Tag.self,
        ChatThread.self,
        ChatMessage.self,
    ])
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
        ModelManager.clearSelection()
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

        await #expect(throws: SharedLlamaInferenceError.noModelSelected) {
            try await SharedLlamaInference.shared.withSession { _ in }
        }

        await SharedLlamaInference.shared._test_withExclusiveLifecycleLock { }
    }

    @Test func withSessionWaitsForExclusiveTestLock() async throws {
        let defaults = UserDefaults.standard
        let savedBookmark = defaults.data(forKey: TestModelUserDefaultsKeys.bookmark)
        let savedLegacy = defaults.string(forKey: TestModelUserDefaultsKeys.legacyPath)
        ModelManager.clearSelection()
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
