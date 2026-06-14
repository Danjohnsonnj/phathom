import PhathomCore
import SwiftUI

struct FocusOutcomeSheet: View {
    let item: ContentItem
    let onPick: (FocusOutcomeKind) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.displayTitle)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        outcomeRow(
                            title: "Reference",
                            hint: "Shelve as reference",
                            kind: .reference
                        )
                        sheetHairline
                        outcomeRow(
                            title: "Takeaway",
                            hint: "Capture what I learned",
                            kind: .takeaway
                        )
                        sheetHairline
                        outcomeRow(
                            title: "Revisit",
                            hint: "Come back later",
                            kind: .revisit
                        )
                        sheetHairline
                        outcomeRow(
                            title: "Release",
                            hint: "No longer matters",
                            kind: .release,
                            destructive: true
                        )
                    }
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .fixedSize(horizontal: false, vertical: true)
                .phathomSheetHeightMeasurable()
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, 24)
            }
            .background(AppPalette.background)
            .navigationTitle("Complete in Focus")
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

    private func outcomeRow(
        title: String,
        hint: String,
        kind: FocusOutcomeKind,
        destructive: Bool = false
    ) -> some View {
        Button {
            onPick(kind)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(destructive ? Color.red : AppPalette.textPrimary)
                Text(hint)
                    .font(.system(size: 15))
                    .foregroundStyle(destructive ? Color.red.opacity(0.72) : AppPalette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
