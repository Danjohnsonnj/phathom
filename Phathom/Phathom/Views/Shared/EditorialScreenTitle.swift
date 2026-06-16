import SwiftUI

/// Large editorial screen title for tab roots and pushed Settings (34pt semibold, 22pt rhythm).
struct EditorialScreenTitle: View {
    let title: String
    var bottomSpacing: CGFloat = AppSpacing.editorialTitleBottom

    var body: some View {
        Text(title)
            .appTypography(.screenTitle)
            .foregroundStyle(AppPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, bottomSpacing)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    EditorialScreenTitle(title: "Library")
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .background(AppPalette.background)
}
