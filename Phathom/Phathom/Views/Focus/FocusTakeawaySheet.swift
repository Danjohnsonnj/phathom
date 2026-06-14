import PhathomCore
import SwiftUI

struct FocusTakeawaySheet: View {
    let item: ContentItem
    let onSave: (String, UUID?) -> Void
    let onCancel: () -> Void

    @State private var takeawayDraft = ""
    @State private var selectedHighlightID: UUID?

    private var highlights: [Highlight] {
        item.highlightsSortedByOffset
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextEditor(text: $takeawayDraft)
                        .frame(minHeight: 120)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(AppPalette.surfaceNested)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(AppPalette.textPrimary)

                    if !highlights.isEmpty {
                        Text("Pin to highlight (optional)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.textPrimary)

                        VStack(spacing: 0) {
                            pinRow(title: "None", highlightID: nil)
                            ForEach(highlights) { highlight in
                                sheetHairline
                                pinRow(
                                    title: highlight.quotedText,
                                    highlightID: highlight.id
                                )
                            }
                        }
                        .background(AppPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        let text = takeawayDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        onSave(String(text.prefix(2_000)), selectedHighlightID)
                    } label: {
                        Text("Save takeaway")
                            .font(.subheadline.weight(.semibold))
                            .phathomCapsuleCTALabel()
                            .foregroundStyle(AppPalette.floralWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(takeawayDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .fixedSize(horizontal: false, vertical: true)
                .phathomSheetHeightMeasurable()
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, 16)
            }
            .background(AppPalette.background)
            .navigationTitle("Takeaway")
            .phathomInlineNavigationTitle()
            .toolbar {
                FlatToolbarTextItem(
                    title: "Cancel",
                    placement: .cancellationAction,
                    foreground: AppPalette.accent,
                    action: onCancel
                )
            }
        }
        .phathomSheetPresentation()
    }

    private func pinRow(title: String, highlightID: UUID?) -> some View {
        Button {
            selectedHighlightID = highlightID
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selectedHighlightID == highlightID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var sheetHairline: some View {
        Rectangle()
            .fill(AppPalette.hairline)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
