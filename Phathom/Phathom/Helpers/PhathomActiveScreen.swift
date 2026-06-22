#if os(iOS)
import UIKit

@MainActor
enum PhathomActiveScreen {
    private static let fallbackBounds = CGRect(x: 0, y: 0, width: 402, height: 874)
    private static let fallbackScale: CGFloat = 3.0

    static var bounds: CGRect {
        activeWindowScene?.screen.bounds ?? fallbackBounds
    }

    static var scale: CGFloat {
        activeWindowScene?.screen.scale ?? fallbackScale
    }

    private static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let foreground = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return foreground
        }
        return scenes.first
    }
}
#endif
