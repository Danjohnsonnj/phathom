import SwiftUI

/// Inline stale nudge banner on Focus tab (mock: `focus-stack-ad-sheets-a.html`).
struct FocusStaleNudgeBanner: View {
    let message: String
    let onKeep: () -> Void
    let onComplete: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .appTypography(.zoneSubtitle)
                .foregroundStyle(AppPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                nudgeAction("Keep", primary: true, action: onKeep)
                nudgeAction("Complete", primary: true, action: onComplete)
                nudgeAction("Remove", primary: false, action: onRemove)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppPalette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }

    private func nudgeAction(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .appTypography(.subsectionHeader)
            .foregroundStyle(primary ? AppPalette.accent : AppPalette.textSecondary)
    }
}
