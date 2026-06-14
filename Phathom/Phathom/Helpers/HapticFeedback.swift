#if os(iOS)
import UIKit
#endif

enum HapticFeedback {
    static func lightImpact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
