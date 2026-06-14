import Foundation
import PhathomCore
import SwiftData

enum MediaDisplayImageLoader {
    /// Load display-sized image: memory cache → coalesced off-main fault + decode.
    static func loadDisplayImage(
        itemID: UUID,
        modelContainer: ModelContainer,
        appearGeneration: Int = 0
    ) async -> PlatformImage? {
        if let cached = MediaDisplayImageCache.shared.image(for: itemID) {
            MediaImageLoadMetrics.logCacheHitIfNeeded(itemID: itemID, appearGeneration: appearGeneration)
            return cached
        }

        let id = itemID
        return await MediaDisplayImageLoadCoordinator.shared.load(
            itemID: itemID,
            modelContainer: modelContainer
        ) { container in
            await loadDisplayImagePipeline(itemID: id, modelContainer: container)
        }
    }

    /// Bumps generation so in-flight loads for `itemID` are discarded; pair with cache removal.
    static func invalidateGeneration(for itemID: UUID) async {
        MediaImageLoadMetrics.clearCacheHitLog(for: itemID)
        await MediaDisplayImageLoadCoordinator.shared.invalidateGeneration(for: itemID)
    }

    /// Start decode before `DetailView` appears (Library navigation).
    static func prewarm(itemID: UUID, contentKind: ContentKind, modelContainer: ModelContainer) {
        guard contentKind == .media else { return }
        Task(priority: .userInitiated) {
            _ = await loadDisplayImage(itemID: itemID, modelContainer: modelContainer)
        }
    }

    private static func loadDisplayImagePipeline(
        itemID: UUID,
        modelContainer: ModelContainer
    ) async -> PlatformImage? {
        await MediaImageLoadMetrics.measureAsync("detail_task") {
            let snapshot = await loadThumbnailSnapshot(itemID: itemID, modelContainer: modelContainer)
            guard let snapshot else { return nil }

            let image = await MediaImageLoadMetrics.measureAsync("decode_off_main") {
                await ThumbnailImageDecoding.decodeOffMain(from: snapshot.data)
            }

            if let image {
                MediaDisplayImageCache.shared.setImage(image, for: itemID)
            }
            return image
        }
    }

    private static func loadThumbnailSnapshot(
        itemID: UUID,
        modelContainer: ModelContainer
    ) async -> MediaThumbnailDataFetcher.ThumbnailSnapshot? {
        let start = ContinuousClock.now
        let snapshot = await MediaThumbnailDataFetcher.fetchThumbnail(
            for: itemID,
            modelContainer: modelContainer
        )
        let ms = MediaImageLoadMetrics.elapsedMilliseconds(since: start)
        if let snapshot {
            MediaImageLoadMetrics.logThumbnailFault(
                byteCount: snapshot.byteCount,
                isJPEG: snapshot.isJPEG,
                durationMs: ms
            )
        }
        return snapshot
    }
}
