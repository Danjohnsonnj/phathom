//
//  PhathomTests.swift
//  PhathomTests
//
//  Created by Daniel Johnson on 4/29/26.
//

import Foundation
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
