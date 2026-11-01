import Foundation
import PhathomCore

enum AnalyzeProgressSettingsStorage {
    static let enabledKey = "phathom.analyzeProgress.enabled"
}

struct AnalyzeProgressTotals: Equatable, Sendable {
    var totalAnalyzeMilliseconds: Int
    var totalCappedCharacters: Int
    var sampleCount: Int

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.totalAnalyzeMilliseconds == rhs.totalAnalyzeMilliseconds
            && lhs.totalCappedCharacters == rhs.totalCappedCharacters
            && lhs.sampleCount == rhs.sampleCount
    }

    nonisolated static let empty = AnalyzeProgressTotals(
        totalAnalyzeMilliseconds: 0,
        totalCappedCharacters: 0,
        sampleCount: 0
    )
}

/// Device-local analyze timing buckets per `ModelPairKey` (UserDefaults only).
struct AnalyzeProgressStore: Sendable {
    nonisolated private static let bucketKeyPrefix = "analyzeProgress.bucket."

    nonisolated(unsafe) let userDefaults: UserDefaults

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

        nonisolated init(
            totalAnalyzeMilliseconds: Int,
            totalCappedCharacters: Int,
            sampleCount: Int
        ) {
            self.totalAnalyzeMilliseconds = totalAnalyzeMilliseconds
            self.totalCappedCharacters = totalCappedCharacters
            self.sampleCount = sampleCount
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            totalAnalyzeMilliseconds = try container.decode(Int.self, forKey: .totalAnalyzeMilliseconds)
            totalCappedCharacters = try container.decode(Int.self, forKey: .totalCappedCharacters)
            sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        }

        nonisolated func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(totalAnalyzeMilliseconds, forKey: .totalAnalyzeMilliseconds)
            try container.encode(totalCappedCharacters, forKey: .totalCappedCharacters)
            try container.encode(sampleCount, forKey: .sampleCount)
        }

        private enum CodingKeys: String, CodingKey {
            case totalAnalyzeMilliseconds
            case totalCappedCharacters
            case sampleCount
        }
    }
}
