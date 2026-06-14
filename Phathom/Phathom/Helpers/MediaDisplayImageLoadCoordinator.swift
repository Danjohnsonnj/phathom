import Foundation
import SwiftData

/// Coalesces concurrent `loadDisplayImage` work per item and drops stale results after thumbnail invalidation.
actor MediaDisplayImageLoadCoordinator {
    static let shared = MediaDisplayImageLoadCoordinator()

    private var inflight: [UUID: Task<PlatformImage?, Never>] = [:]
    private var generation: [UUID: UInt64] = [:]

    func invalidateGeneration(for itemID: UUID) {
        generation[itemID, default: 0] &+= 1
    }

    func load(
        itemID: UUID,
        modelContainer: ModelContainer,
        performLoad: @Sendable @escaping (ModelContainer) async -> PlatformImage?
    ) async -> PlatformImage? {
        let generationAtStart = generation[itemID, default: 0]

        if let existing = inflight[itemID] {
            let result = await existing.value
            guard generation[itemID, default: 0] == generationAtStart else { return nil }
            return result
        }

        let task = Task<PlatformImage?, Never> {
            await performLoad(modelContainer)
        }
        inflight[itemID] = task
        let result = await task.value
        inflight.removeValue(forKey: itemID)

        guard generation[itemID, default: 0] == generationAtStart else { return nil }
        return result
    }
}
