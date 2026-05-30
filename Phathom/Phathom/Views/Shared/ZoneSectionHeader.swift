import SwiftUI

/// Parent zone header — 17pt semibold title with optional 15pt secondary subtitle.
///
/// Subsection tier (Detail Tags / Summary / Key Figures): use ``DetailAISubsectionHeader``.
struct ZoneSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.34)
                .foregroundStyle(AppPalette.textPrimary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Zone parent") {
    VStack(alignment: .leading, spacing: 16) {
        ZoneSectionHeader(
            title: "AI Models",
            subtitle: "Primary and optional tagging models."
        )
        DetailAISubsectionHeader(title: "Tags")
    }
    .padding(.horizontal, AppSpacing.screenHorizontal)
    .background(AppPalette.background)
}
