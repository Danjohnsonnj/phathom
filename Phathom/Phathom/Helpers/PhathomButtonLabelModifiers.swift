import SwiftUI

// MARK: - CTA label sizing (design-tokens §5.1 — no tail truncation on buttons)

extension View {
    /// Toolbar / chrome text actions — full string visible (e.g. Close, Cancel, Done).
    func phathomToolbarTextLabel() -> some View {
        fixedSize(horizontal: true, vertical: false)
    }

    /// Full-width capsule button title — wrap before ellipsis; no `.truncationMode(.tail)`.
    func phathomCapsuleCTALabel(lineLimit: Int = 2) -> some View {
        multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }
}
