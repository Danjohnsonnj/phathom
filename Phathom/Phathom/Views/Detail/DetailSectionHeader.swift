import SwiftUI

struct DetailAISubsectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .appTypography(.subsectionHeader)
            .foregroundStyle(AppPalette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DetailAITagsSectionHeader: View {
    let title: String
    let isEditMode: Bool
    let onEditToggle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            DetailAISubsectionHeader(title: title)
            Spacer()
            Button(isEditMode ? "Done" : "Edit") {
                onEditToggle()
            }
            .appTypography(.disclosureLabel)
            .buttonStyle(.plain)
            .foregroundStyle(AppPalette.accent)
            .accessibilityLabel(isEditMode ? "Done editing tags" : "Edit tags")
        }
    }
}
