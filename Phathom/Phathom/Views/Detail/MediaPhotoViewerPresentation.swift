import SwiftUI

/// Payload for `DetailView` full-screen photo viewer (`fullScreenCover(item:)` / macOS sheet).
struct MediaPhotoViewerPresentation: Identifiable {
    /// Fresh per present so repeat opens after Done get a new cover identity.
    let presentationID: UUID
    let itemID: UUID
    let image: PlatformImage
    let accessibilityLabel: String

    var id: UUID { presentationID }
}
