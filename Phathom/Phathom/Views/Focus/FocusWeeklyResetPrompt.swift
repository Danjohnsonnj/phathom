import PhathomCore
import SwiftUI

/// Weekly Focus check-in banner on Focus tab (Phase B5).
struct FocusWeeklyResetPrompt: View {
    let openSlotCount: Int
    let activeCount: Int
    let onGoToLibrary: () -> Void
    let onDismiss: () -> Void

    private var message: String {
        if activeCount == 0 {
            return "Pick up to \(FocusStackConstants.maxActiveEntries) items from Library for this week's Focus."
        }
        if openSlotCount > 0 {
            return "You have \(openSlotCount) open Focus \(openSlotCount == 1 ? "slot" : "slots") — review your stack or add from Library."
        }
        return "Your Focus stack is full — review what still matters this week."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Focus check-in")
                .appTypography(.disclosureLabel)
                .foregroundStyle(AppPalette.textPrimary)

            Text(message)
                .appTypography(.zoneSubtitle)
                .foregroundStyle(AppPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button("Go to Library", action: onGoToLibrary)
                    .appTypography(.subsectionHeader)
                    .foregroundStyle(AppPalette.accent)

                Button("Not now", action: onDismiss)
                    .appTypography(.subsectionHeader)
                    .foregroundStyle(AppPalette.textSecondary)

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
    }
}
