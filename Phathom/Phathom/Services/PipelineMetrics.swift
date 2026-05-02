import Foundation

/// Optional per-stage timing for background analyze; remove this file and call sites to drop logging.
enum PipelineMetrics {
    @discardableResult
    nonisolated static func time<T>(
        _ stage: String,
        itemID: UUID,
        _ work: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        let value = try await work()
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        print("[PhathomPipeline] stage=\(stage) item=\(itemID.uuidString) ms=\(ms)")
        return value
    }

    /// Log elapsed ms for work already executed (avoids passing DB-mutating closures through a generic helper).
    nonisolated static func logSyncElapsed(_ stage: String, itemID: UUID, start: Date) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        print("[PhathomPipeline] stage=\(stage) item=\(itemID.uuidString) ms=\(ms)")
    }
}
