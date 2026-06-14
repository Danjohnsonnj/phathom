import PhathomCore
import SwiftUI

/// Library → Detail push with media display prewarm before `DetailView` builds.
struct LibraryDetailRoute: View {
    let item: ContentItem
    let onRelatedItemSelected: (UUID) -> Void

    init(item: ContentItem, onRelatedItemSelected: @escaping (UUID) -> Void) {
        self.item = item
        self.onRelatedItemSelected = onRelatedItemSelected
        #if os(iOS)
        if item.kind == .media, let modelContainer = BackgroundPipeline.modelContainerOrNil() {
            MediaDisplayImageLoader.prewarm(
                itemID: item.id,
                contentKind: item.kind,
                modelContainer: modelContainer
            )
        }
        #endif
    }

    var body: some View {
        DetailView(item: item, onRelatedItemSelected: onRelatedItemSelected)
    }
}
