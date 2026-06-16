import SwiftUI

/// Two-tier empty / filter-empty copy (17pt semibold title + 15pt secondary hint). design-tokens.md §4.
struct EditorialTwoTierEmptyState: View {
    let title: String
    let hint: String
    var hintMaxWidth: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .appTypography(.emptyPrimary)
                .foregroundStyle(AppPalette.textPrimary)
            Text(hint)
                .appTypography(.emptyHint)
                .foregroundStyle(AppPalette.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: hintMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EditorialTwoTierEmptyState(
        title: "No items match these filters",
        hint: "Try changing Type, Status or Category."
    )
    .padding(.horizontal, AppSpacing.screenHorizontal)
    .background(AppPalette.background)
}
