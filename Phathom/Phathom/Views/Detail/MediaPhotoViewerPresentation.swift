#if os(iOS)
import UIKit

/// Payload for `DetailView` full-screen photo viewer (`fullScreenCover(item:)`).
struct MediaPhotoViewerPresentation: Identifiable {
    /// Fresh per present so repeat opens after Done get a new cover identity.
    let presentationID: UUID
    let itemID: UUID
    let image: UIImage
    let accessibilityLabel: String

    var id: UUID { presentationID }
}
#endif
