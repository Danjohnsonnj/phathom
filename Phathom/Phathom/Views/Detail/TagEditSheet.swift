import PhathomCore
import SwiftUI

enum TagEditSheetMode {
    case add
    case edit(originalTagName: String)

    var title: String {
        switch self {
        case .add:
            return "Add Tag"
        case .edit:
            return "Edit Tag"
        }
    }

    var isEditingExistingTag: Bool {
        if case .edit = self { return true }
        return false
    }
}

struct TagEditSheet: View {
    let title: String
    @Binding var text: String
    let showsDelete: Bool
    let saveLabel: String
    let onSave: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    let validationMessage: String?
    let errorMessage: String?

    private var normalizedDraft: String? {
        TagNameNormalizer.normalize(text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                TextField("Tag", text: $text)
                    .appTypography(.body)
                    .textFieldStyle(.plain)
                    .phathomAutocapitalizationNever()
                    .autocorrectionDisabled()
                    .foregroundStyle(AppPalette.textPrimary)
                    .padding(10)
                    .background(AppPalette.surfaceNested)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let validationMessage {
                    Text(validationMessage)
                        .appTypography(.meta)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .appTypography(.meta)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onSave) {
                    Text(saveLabel)
                        .phathomCapsuleCTALabel()
                        .appTypography(.disclosureLabel)
                        .foregroundStyle(AppPalette.floralWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppPalette.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(normalizedDraft == nil)

                if showsDelete, let onDelete {
                    Button(action: onDelete) {
                        Text("Delete tag")
                            .phathomCapsuleCTALabel()
                            .appTypography(.subsectionHeader)
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.surfaceNested)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                }
                .fixedSize(horizontal: false, vertical: true)
                .phathomSheetHeightMeasurable()
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, 16)
            }
            .background(AppPalette.background)
            .navigationTitle(title)
            .phathomInlineNavigationTitle()
            .toolbar {
                FlatToolbarTextItem(
                    title: "Close",
                    placement: .cancellationAction,
                    foreground: AppPalette.accent,
                    action: onCancel
                )
            }
        }
        .phathomSheetPresentation()
    }
}
