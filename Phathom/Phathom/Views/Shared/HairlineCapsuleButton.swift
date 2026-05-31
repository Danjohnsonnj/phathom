import SwiftUI

/// Full-width secondary action — hairline stroke on a capsule (design-tokens §5.1).
struct HairlineCapsuleButton: View {
    let title: String
    let foreground: Color
    var disabled: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .tracking(-0.15)
            .foregroundStyle(foreground)
            .phathomCapsuleCTALabel()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .overlay {
                Capsule()
                    .stroke(AppPalette.hairline, lineWidth: 1)
            }
            .opacity(disabled ? 0.6 : 1.0)
    }
}
