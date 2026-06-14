#if os(iOS)
import SwiftUI
import UIKit

/// Presents `UIActivityViewController` inside a sheet so dismiss always clears SwiftUI state
/// (avoids touch-deadlock after Copy Link from `ShareLink` in `safeAreaInset` push chrome).
struct ShareActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                onDismiss()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
