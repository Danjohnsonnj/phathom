//
//  AnalyzeProgressStoreTests.swift
//  PhathomTests
//

import Foundation
import Testing
@testable import Phathom

struct AnalyzeProgressStoreTests {

    private static let primaryA = ModelFileIdentity(filename: "primary-a.gguf", byteCount: 1_000_000_000)
    private static let taggingA = ModelFileIdentity(filename: "tagging-a.gguf", byteCount: 500_000_000)
    private static let primaryB = ModelFileIdentity(filename: "primary-b.gguf", byteCount: 2_000_000_000)

    private func makeStore() -> (AnalyzeProgressStore, String) {
        let suite = "com.phathom.analyzeProgressTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (AnalyzeProgressStore(userDefaults: defaults), suite)
    }

    private func tearDown(suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test func twoPairsDoNotMix() {
        let (store, suite) = makeStore()
        defer { tearDown(suite: suite) }

        let keyA = ModelPairKey.forEstimate(primary: Self.primaryA, configuredTagging: Self.taggingA)
        let keyB = ModelPairKey.forEstimate(primary: Self.primaryB, configuredTagging: nil)

        store.record(key: keyA, analyzeMilliseconds: 10_000, sourceCharacterCount: 1_000)
        store.record(key: keyB, analyzeMilliseconds: 20_000, sourceCharacterCount: 2_000)

        let totalsA = store.lookup(key: keyA)
        let totalsB = store.lookup(key: keyB)

        #expect(totalsA.sampleCount == 1)
        #expect(totalsA.totalAnalyzeMilliseconds == 10_000)
        #expect(totalsA.totalCappedCharacters == 1_000)

        #expect(totalsB.sampleCount == 1)
        #expect(totalsB.totalAnalyzeMilliseconds == 20_000)
        #expect(totalsB.totalCappedCharacters == 2_000)
    }

    @Test func sameFilenameDifferentByteCountIsSeparateBucket() {
        let (store, suite) = makeStore()
        defer { tearDown(suite: suite) }

        let small = ModelFileIdentity(filename: "shared-name.gguf", byteCount: 100)
        let large = ModelFileIdentity(filename: "shared-name.gguf", byteCount: 200)
        let keySmall = ModelPairKey.forEstimate(primary: small, configuredTagging: nil)
        let keyLarge = ModelPairKey.forEstimate(primary: large, configuredTagging: nil)

        store.record(key: keySmall, analyzeMilliseconds: 1_000, sourceCharacterCount: 100)
        store.record(key: keyLarge, analyzeMilliseconds: 9_000, sourceCharacterCount: 900)

        #expect(store.lookup(key: keySmall).sampleCount == 1)
        #expect(store.lookup(key: keySmall).totalAnalyzeMilliseconds == 1_000)
        #expect(store.lookup(key: keyLarge).sampleCount == 1)
        #expect(store.lookup(key: keyLarge).totalAnalyzeMilliseconds == 9_000)
    }

    @Test func storageUsesPrimaryPlusPrimaryWhenTaggingAbsentFallbackOrNotRun() {
        let primary = Self.primaryA
        let configured = Self.taggingA

        let missing = ModelPairKey.forStorage(
            primary: primary,
            configuredTagging: nil,
            taggingRan: true,
            usedPrimaryFallback: false,
            ranTaggingIdentity: configured
        )
        #expect(missing == ModelPairKey(primary: primary, tagging: primary))

        let notRun = ModelPairKey.forStorage(
            primary: primary,
            configuredTagging: configured,
            taggingRan: false,
            usedPrimaryFallback: false,
            ranTaggingIdentity: configured
        )
        #expect(notRun == ModelPairKey(primary: primary, tagging: primary))

        let fallback = ModelPairKey.forStorage(
            primary: primary,
            configuredTagging: configured,
            taggingRan: true,
            usedPrimaryFallback: true,
            ranTaggingIdentity: configured
        )
        #expect(fallback == ModelPairKey(primary: primary, tagging: primary))
    }

    @Test func storageUsesDistinctTaggingWhenItRan() {
        let primary = Self.primaryA
        let tagging = Self.taggingA
        let key = ModelPairKey.forStorage(
            primary: primary,
            configuredTagging: tagging,
            taggingRan: true,
            usedPrimaryFallback: false,
            ranTaggingIdentity: tagging
        )
        #expect(key == ModelPairKey(primary: primary, tagging: tagging))
    }

    @Test func estimateKeyUsesConfiguredTaggingWhenPresent() {
        let primary = Self.primaryA
        let tagging = Self.taggingA
        #expect(
            ModelPairKey.forEstimate(primary: primary, configuredTagging: tagging)
                == ModelPairKey(primary: primary, tagging: tagging)
        )
        #expect(
            ModelPairKey.forEstimate(primary: primary, configuredTagging: nil)
                == ModelPairKey(primary: primary, tagging: primary)
        )
    }

    @Test func fallbackStorageRecordsOnPrimaryPlusPrimary() {
        let (store, suite) = makeStore()
        defer { tearDown(suite: suite) }

        let storageKey = ModelPairKey.forStorage(
            primary: Self.primaryA,
            configuredTagging: Self.taggingA,
            taggingRan: true,
            usedPrimaryFallback: true,
            ranTaggingIdentity: Self.taggingA
        )
        #expect(storageKey.tagging == Self.primaryA)

        store.record(key: storageKey, analyzeMilliseconds: 5_000, sourceCharacterCount: 500)
        let totals = store.lookup(key: storageKey)
        #expect(totals.sampleCount == 1)

        let estimatePair = ModelPairKey.forEstimate(primary: Self.primaryA, configuredTagging: Self.taggingA)
        #expect(store.lookup(key: estimatePair).sampleCount == 0)
    }

    @Test func sampleCountIsPerKey() {
        let (store, suite) = makeStore()
        defer { tearDown(suite: suite) }

        let keyA = ModelPairKey.forEstimate(primary: Self.primaryA, configuredTagging: nil)
        let keyB = ModelPairKey.forEstimate(primary: Self.primaryB, configuredTagging: nil)

        for _ in 0 ..< 3 {
            store.record(key: keyA, analyzeMilliseconds: 1_000, sourceCharacterCount: 100)
        }

        #expect(store.lookup(key: keyA).sampleCount == 3)
        #expect(store.lookup(key: keyB).sampleCount == 0)
    }

    @Test func recordingZeroCharactersDoesNotCreateUsableRate() {
        let (store, suite) = makeStore()
        defer { tearDown(suite: suite) }

        let key = ModelPairKey.forEstimate(primary: Self.primaryA, configuredTagging: nil)
        store.record(key: key, analyzeMilliseconds: 9_999, sourceCharacterCount: 0)

        let totals = store.lookup(key: key)
        #expect(totals == .empty)
        #expect(store.rateMillisecondsPerCharacter(for: key) == nil)
    }
}
