import Foundation

struct AnalyzeProgressClockEntry: Sendable {
    var estimateKey: ModelPairKey
    var startDate: Date
}

/// In-memory analyze pass timing keyed by pipeline item id (slice 3).
enum AnalyzeProgressClock {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var entries: [UUID: AnalyzeProgressClockEntry] = [:]

        nonisolated func begin(itemID: UUID, estimateKey: ModelPairKey) {
            lock.lock()
            defer { lock.unlock() }
            entries[itemID] = AnalyzeProgressClockEntry(estimateKey: estimateKey, startDate: Date())
        }

        nonisolated func end(itemID: UUID) {
            lock.lock()
            defer { lock.unlock() }
            entries.removeValue(forKey: itemID)
        }

        nonisolated func startDate(for itemID: UUID) -> Date? {
            lock.lock()
            defer { lock.unlock() }
            return entries[itemID]?.startDate
        }

        nonisolated func entry(for itemID: UUID) -> AnalyzeProgressClockEntry? {
            lock.lock()
            defer { lock.unlock() }
            return entries[itemID]
        }
    }

    private nonisolated(unsafe) static let box = Box()

    nonisolated static func begin(itemID: UUID, estimateKey: ModelPairKey) {
        box.begin(itemID: itemID, estimateKey: estimateKey)
    }

    nonisolated static func end(itemID: UUID) {
        box.end(itemID: itemID)
    }

    nonisolated static func startDate(for itemID: UUID) -> Date? {
        box.startDate(for: itemID)
    }

    nonisolated static func entry(for itemID: UUID) -> AnalyzeProgressClockEntry? {
        box.entry(for: itemID)
    }
}
