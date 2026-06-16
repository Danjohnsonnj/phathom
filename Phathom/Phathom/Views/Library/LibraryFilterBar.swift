import PhathomCore
import SwiftUI

/// Filter controls above the Library list (`popover`, not `Menu`).
///
/// Static labels (**Type**, **Status**, **Category**) sit above value-only capsules so narrow widths avoid hyphen-wrapping.
///
/// Column widths: **27.5% / 27.5% / 45%** of row width minus the two **`HStack` spacings** (10 pt each).
struct LibraryFilterBar: View {
    @Binding var filterKindRaw: String
    @Binding var filterStatusRaw: String
    /// Matches `@AppStorage` raw: `""` = pass-through; partial = comma-separated tokens including ``LibraryCategoryFilterStorage/uncategorizedRaw``.
    @Binding var filterCategoryRaw: String

    var categories: [PhathomCore.Category]

    @State private var showKindPicker = false
    @State private var showStatusPicker = false
    @State private var showCategoryPicker = false

    private static let columnSpacing: CGFloat = 10
    private static let typeColumnFraction: CGFloat = 0.275
    private static let statusColumnFraction: CGFloat = 0.275
    private static let categoryColumnFraction: CGFloat = 0.45
    /// Stable height so `GeometryReader` does not expand the Library chrome vertically.
    private static let barEstimatedHeight: CGFloat = 72

    var body: some View {
        GeometryReader { geo in
            let gapTotal = Self.columnSpacing * 2
            let usableWidth = max(geo.size.width - gapTotal, 0)
            HStack(alignment: .top, spacing: Self.columnSpacing) {
                filterColumn(title: "Type", width: usableWidth * Self.typeColumnFraction) { kindTrigger }
                filterColumn(title: "Status", width: usableWidth * Self.statusColumnFraction) { statusTrigger }
                filterColumn(title: "Category", width: usableWidth * Self.categoryColumnFraction) { categoryTrigger }
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
        .frame(height: Self.barEstimatedHeight)
    }

    /// Title row + capsule in a fixed-width column fraction of the row.
    private func filterColumn(title: String, width: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .appTypography(.filterLabel)
                .foregroundStyle(AppPalette.textSecondary)
                .phathomToolbarTextLabel()
                .padding(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 0))
            content()
        }
        .frame(width: width, alignment: .leading)
    }

    private var kindTrigger: some View {
        Button {
            showStatusPicker = false
            showCategoryPicker = false
            showKindPicker = true
        } label: {
            FilterValueCapsule(value: kindLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by type")
        .accessibilityValue(kindAccessibilityValue)
        .popover(isPresented: $showKindPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            kindPickerPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var statusTrigger: some View {
        Button {
            showKindPicker = false
            showCategoryPicker = false
            showStatusPicker = true
        } label: {
            FilterValueCapsule(value: statusLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by status")
        .accessibilityValue(statusAccessibilityValue)
        .popover(isPresented: $showStatusPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            statusPickerPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var categoryTrigger: some View {
        Button {
            showKindPicker = false
            showStatusPicker = false
            showCategoryPicker = true
        } label: {
            FilterValueCapsule(value: categoryLabel, allowsTailTruncation: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by category")
        .accessibilityValue(categoryAccessibilityValue)
        .popover(isPresented: $showCategoryPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            categoryPickerPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var kindPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LibraryFilterCodec.kindDisplayOrder, id: \.self) { kind in
                filterPopoverRow(
                    title: kindPickerTitle(kind),
                    selected: LibraryFilterCodec.isKindSelected(kind, raw: filterKindRaw),
                    disabled: LibraryFilterCodec.isKindToggleDisabled(kind, raw: filterKindRaw)
                ) {
                    guard let updated = LibraryFilterCodec.toggleKind(kind, in: filterKindRaw) else { return }
                    filterKindRaw = updated
                }
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 6)
    }

    private var statusPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LibraryFilterCodec.statusDisplayOrder, id: \.self) { status in
                filterPopoverRow(
                    title: ReadStatusPresentation.label(for: status),
                    selected: LibraryFilterCodec.isStatusSelected(status, raw: filterStatusRaw),
                    disabled: LibraryFilterCodec.isStatusToggleDisabled(status, raw: filterStatusRaw)
                ) {
                    guard let updated = LibraryFilterCodec.toggleStatus(status, in: filterStatusRaw) else { return }
                    filterStatusRaw = updated
                }
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 6)
    }

    private var sortedCategoryNamesAlphabetically: [String] {
        categories
            .sorted {
                CategoryDisplayFormatter.displayName($0.name).localizedCaseInsensitiveCompare(
                    CategoryDisplayFormatter.displayName($1.name)
                ) == .orderedAscending
            }
            .map(\.name)
    }

    private var categoryUniverse: Set<String> {
        LibraryFilterCodec.categoryUniverse(categoryNames: sortedCategoryNamesAlphabetically)
    }

    private var categoryPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterPopoverRow(
                title: "Uncategorized",
                selected: LibraryFilterCodec.isCategorySelected(
                    LibraryCategoryFilterStorage.uncategorizedRaw,
                    raw: filterCategoryRaw,
                    universe: categoryUniverse
                ),
                disabled: LibraryFilterCodec.isCategoryToggleDisabled(
                    LibraryCategoryFilterStorage.uncategorizedRaw,
                    raw: filterCategoryRaw,
                    universe: categoryUniverse
                )
            ) {
                guard let updated = LibraryFilterCodec.toggleCategory(
                    LibraryCategoryFilterStorage.uncategorizedRaw,
                    in: filterCategoryRaw,
                    universe: categoryUniverse
                ) else { return }
                filterCategoryRaw = updated
            }
            ForEach(sortedCategoryNamesAlphabetically, id: \.self) { name in
                let label = CategoryDisplayFormatter.displayName(name)
                filterPopoverRow(
                    title: label,
                    selected: LibraryFilterCodec.isCategorySelected(name, raw: filterCategoryRaw, universe: categoryUniverse),
                    disabled: LibraryFilterCodec.isCategoryToggleDisabled(name, raw: filterCategoryRaw, universe: categoryUniverse)
                ) {
                    guard let updated = LibraryFilterCodec.toggleCategory(name, in: filterCategoryRaw, universe: categoryUniverse) else { return }
                    filterCategoryRaw = updated
                }
            }
        }
        .frame(minWidth: 240)
        .padding(.vertical, 6)
    }

    private func filterPopoverRow(
        title: String,
        selected: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .appTypography(.body)
                    .foregroundStyle(disabled ? AppPalette.textSecondary : AppPalette.textPrimary)
                Spacer(minLength: 12)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var kindLabel: String {
        LibraryFilterCodec.kindCapsuleLabel(raw: filterKindRaw)
    }

    private var statusLabel: String {
        LibraryFilterCodec.statusCapsuleLabel(raw: filterStatusRaw)
    }

    private var categoryLabel: String {
        LibraryFilterCodec.categoryCapsuleLabel(raw: filterCategoryRaw, sortedCategoryNames: sortedCategoryNamesAlphabetically)
    }

    private var kindAccessibilityValue: String {
        LibraryFilterCodec.kindAccessibilityValue(raw: filterKindRaw)
    }

    private var statusAccessibilityValue: String {
        LibraryFilterCodec.statusAccessibilityValue(raw: filterStatusRaw)
    }

    private var categoryAccessibilityValue: String {
        LibraryFilterCodec.categoryAccessibilityValue(raw: filterCategoryRaw, sortedCategoryNames: sortedCategoryNamesAlphabetically)
    }

    private func kindPickerTitle(_ kind: ContentKind) -> String {
        switch kind {
        case .web: return "Web"
        case .media: return "Media"
        case .note: return "Notes"
        }
    }
}

/// Capsule containing only the displayed value + chevron (labels live above in ``LibraryFilterBar``).
private struct FilterValueCapsule: View {
    let value: String
    var allowsTailTruncation: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            valueLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppPalette.surface))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var valueLabel: some View {
        let text = Text(value)
            .appTypography(.disclosureLabel)
            .foregroundStyle(AppPalette.textPrimary)
        if allowsTailTruncation {
            text
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            text
                .phathomToolbarTextLabel()
        }
    }
}

#Preview("Default width") {
    struct Binder: View {
        @State private var kindRaw = ""
        @State private var statusRaw = ""
        @State private var categoryRaw = ""

        var body: some View {
            LibraryFilterBar(
                filterKindRaw: $kindRaw,
                filterStatusRaw: $statusRaw,
                filterCategoryRaw: $categoryRaw,
                categories: []
            )
            .padding()
        }
    }
    return Binder()
        .background(AppPalette.background)
}

#Preview("Narrow (~SE)") {
    struct Binder: View {
        @State private var kindRaw = ""
        @State private var statusRaw = ""
        @State private var categoryRaw = ""

        var body: some View {
            LibraryFilterBar(
                filterKindRaw: $kindRaw,
                filterStatusRaw: $statusRaw,
                filterCategoryRaw: $categoryRaw,
                categories: []
            )
            .padding(.horizontal, 16)
            .frame(width: 320)
        }
    }
    return Binder()
        .background(AppPalette.background)
}
