import Foundation

enum AnalyzeProgressSettingsStorage {
    static let enabledKey = "phathom.analyzeProgress.enabled"
}

struct AnalyzeProgressTotals: Equatable, Sendable {
    var totalAnalyzeMilliseconds: Int
    var totalCappedCharacters: Int
    var sampleCount: Int

    nonisolated static let empty = AnalyzeProgressTotals(
        totalAnalyzeMilliseconds: 0,
        totalCappedCharacters: 0,
        sampleCount: 0
    )
}

/// Device-local analyze timing buckets per `ModelPairKey` (UserDefaults only).
struct AnalyzeProgressStore: Sendable {
    private static let bucketKeyPrefix = "analyzeProgress.bucket."

    let userDefaults: UserDefaults

    nonisolated init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    nonisolated static func makeStandard() -> AnalyzeProgressStore {
        AnalyzeProgressStore(userDefaults: .standard)
    }

    nonisolated func lookup(key: ModelPairKey) -> AnalyzeProgressTotals {
        guard let data = userDefaults.data(forKey: Self.storageKey(for: key)),
              let stored = try? JSONDecoder().decode(StoredBucket.self, from: data)
        else {
            return .empty
        }
        return AnalyzeProgressTotals(
            totalAnalyzeMilliseconds: stored.totalAnalyzeMilliseconds,
            totalCappedCharacters: stored.totalCappedCharacters,
            sampleCount: stored.sampleCount
        )
    }

    /// Adds one finished analyze pass. Ignores zero capped source length (no sample, no divide-by-zero rate).
    nonisolated func record(
        key: ModelPairKey,
        analyzeMilliseconds: Int,
        sourceCharacterCount: Int
    ) {
        let capped = AnalyzeProgressEstimator.cappedCharacterCount(for: sourceCharacterCount)
        guard capped > 0 else { return }
        guard analyzeMilliseconds >= 0 else { return }

        var totals = lookup(key: key)
        totals.totalAnalyzeMilliseconds += analyzeMilliseconds
        totals.totalCappedCharacters += capped
        totals.sampleCount += 1
        persist(totals, key: key)
    }

    nonisolated func rateMillisecondsPerCharacter(for key: ModelPairKey) -> Double? {
        let totals = lookup(key: key)
        return AnalyzeProgressEstimator.rateMillisecondsPerCharacter(
            totalAnalyzeMilliseconds: totals.totalAnalyzeMilliseconds,
            totalCappedCharacters: totals.totalCappedCharacters
        )
    }

    private nonisolated static func storageKey(for key: ModelPairKey) -> String {
        bucketKeyPrefix + key.persistenceToken
    }

    private nonisolated func persist(_ totals: AnalyzeProgressTotals, key: ModelPairKey) {
        let stored = StoredBucket(
            totalAnalyzeMilliseconds: totals.totalAnalyzeMilliseconds,
            totalCappedCharacters: totals.totalCappedCharacters,
            sampleCount: totals.sampleCount
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        userDefaults.set(data, forKey: Self.storageKey(for: key))
    }

    private struct StoredBucket: Codable {
        var totalAnalyzeMilliseconds: Int
        var totalCappedCharacters: Int
        var sampleCount: Int
    }
}
