import PhathomCore
import SwiftUI

struct FocusSwapSheet: View {
    let incomingItem: ContentItem
    let entries: [FocusEntry]
    let onSwap: (FocusEntry) -> Void
    let onCancel: () -> Void

    @State private var selectedEntryID: UUID?

    private static let thumbSize: CGFloat = 40

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Release one item to add")
                            .font(.system(size: 15))
                            .foregroundStyle(AppPalette.textSecondary)
                        Text(incomingItem.displayTitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppPalette.textPrimary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            if entry.id != entries.first?.id {
                                sheetHairline
                            }
                            swapRow(for: entry)
                        }
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
            .navigationTitle("Stack is full")
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

    @ViewBuilder
    private func swapRow(for entry: FocusEntry) -> some View {
        if let item = entry.contentItem {
            let isSelected = selectedEntryID == entry.id
            HStack(alignment: .center, spacing: 12) {
                ThumbnailView(
                    thumbnailData: item.thumbnailData,
                    colorHex: item.thumbnailColorHex,
                    contentKind: item.kind,
                    size: Self.thumbSize,
                    cornerRadius: 5
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppPalette.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    swapMeta(for: item, entry: entry)
                }

                if isSelected {
                    Button {
                        onSwap(entry)
                    } label: {
                        Text("Release")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.accent)
                            .phathomToolbarTextLabel()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppPalette.accent.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedEntryID = entry.id
            }
        }
    }

    @ViewBuilder
    private func swapMeta(for item: ContentItem, entry: FocusEntry) -> some View {
        HStack(spacing: 6) {
            Text(daysInFocusLabel(for: entry))
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.textSecondary.opacity(0.72))

            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.textSecondary.opacity(0.35))

            switch item.readState {
            case .new:
                Circle()
                    .fill(AppPalette.accent)
                    .frame(width: 6, height: 6)
            case .read, .filed:
                Text(ReadStatusPresentation.label(for: item.readState))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.textSecondary.opacity(0.65))
            }
        }
    }

    private func daysInFocusLabel(for entry: FocusEntry) -> String {
        let days = FocusCalendar.wholeDays(from: entry.addedAt, to: .now)
        if days == 1 {
            return "1 day in focus"
        }
        return "\(days) days in focus"
    }

    private var sheetHairline: some View {
        Rectangle()
            .fill(AppPalette.hairline)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
