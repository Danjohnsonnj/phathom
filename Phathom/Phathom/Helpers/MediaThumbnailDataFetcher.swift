#if os(iOS)
import Foundation
import PhathomCore
import SwiftData

enum MediaThumbnailDataFetcher {
    struct ThumbnailSnapshot: Sendable {
        let data: Data
        let byteCount: Int
        let isJPEG: Bool
    }

    enum TestSupport {
        nonisolated(unsafe) static var fetchCount = 0
        nonisolated(unsafe) static var artificialDelayNs: UInt64 = 0
    }

    /// Copies `thumbnailData` using a dedicated `ModelContext` off the caller's actor.
    static func fetchThumbnail(for itemID: UUID, modelContainer: ModelContainer) async -> ThumbnailSnapshot? {
        TestSupport.fetchCount += 1
        if TestSupport.artificialDelayNs > 0 {
            try? await Task.sleep(nanoseconds: TestSupport.artificialDelayNs)
        }
        let container = modelContainer
        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let targetID = itemID
            var descriptor = FetchDescriptor<ContentItem>(
                predicate: #Predicate<ContentItem> { $0.id == targetID }
            )
            descriptor.fetchLimit = 1
            guard let item = try? context.fetch(descriptor).first,
                item.contentKind == ContentKind.media.rawValue,
                let data = item.thumbnailData,
                !data.isEmpty
            else {
                return nil
            }
            let isJPEG = data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8
            return ThumbnailSnapshot(data: data, byteCount: data.count, isJPEG: isJPEG)
        }.value
    }
}
#endif
