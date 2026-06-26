import Foundation
#if os(iOS)
import SafariServices
import SwiftUI
#endif

/// `URL` isn't `Identifiable`, but `.sheet(item:)` requires it. Wraps a URL for sheet presentation.
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#if os(iOS)
/// Presents a tapped link in a dismissable in-app browser.
struct SafariSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
