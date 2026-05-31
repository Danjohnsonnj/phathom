import PhathomCore
import SwiftUI

/// Filter controls above the Library list (`popover`, not `Menu`).
///
/// Static labels (**Type**, **Status**, **Category**) sit above value-only capsules so narrow widths avoid hyphen-wrapping.
///
/// Column widths: **27.5% / 27.5% / 45%** of row width minus the two **`HStack` spacings** (10 pt each).
struct LibraryFilterBar: View {
    @Binding var selectedKind: ContentKind?
    @Binding var selectedStatus: ReadStatus?
    /// Matches `@AppStorage` raw: `""` = All; ``LibraryCategoryFilterStorage/uncategorizedRaw`` = Uncategorized only; otherwise kebab stored name.
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
                .font(.subheadline.weight(.light))
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
        .accessibilityValue(kindLabel)
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
        .accessibilityValue(statusLabel)
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
            FilterValueCapsule(value: categoryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by category")
        .accessibilityValue(categoryLabel)
        .popover(isPresented: $showCategoryPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            categoryPickerPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var kindPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterPopoverRow(title: "All", selected: selectedKind == nil) {
                selectedKind = nil
                showKindPicker = false
            }
            filterPopoverRow(title: "Web", selected: selectedKind == .web) {
                selectedKind = .web
                showKindPicker = false
            }
            filterPopoverRow(title: "Media", selected: selectedKind == .media) {
                selectedKind = .media
                showKindPicker = false
            }
            filterPopoverRow(title: "Notes", selected: selectedKind == .note) {
                selectedKind = .note
                showKindPicker = false
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 6)
    }

    private var statusPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterPopoverRow(title: "All", selected: selectedStatus == nil) {
                selectedStatus = nil
                showStatusPicker = false
            }
            filterPopoverRow(title: "New", selected: selectedStatus == .new) {
                selectedStatus = .new
                showStatusPicker = false
            }
            filterPopoverRow(title: "Read", selected: selectedStatus == .read) {
                selectedStatus = .read
                showStatusPicker = false
            }
            filterPopoverRow(title: "Filed", selected: selectedStatus == .filed) {
                selectedStatus = .filed
                showStatusPicker = false
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 6)
    }

    private var sortedCategoriesAlphabetically: [PhathomCore.Category] {
        categories.sorted {
            CategoryDisplayFormatter.displayName($0.name).localizedCaseInsensitiveCompare(
                CategoryDisplayFormatter.displayName($1.name)
            ) == .orderedAscending
        }
    }

    private var categoryPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterPopoverRow(title: "All", selected: filterCategoryRaw.isEmpty) {
                filterCategoryRaw = ""
                showCategoryPicker = false
            }
            filterPopoverRow(title: "Uncategorized", selected: filterCategoryRaw == LibraryCategoryFilterStorage.uncategorizedRaw) {
                filterCategoryRaw = LibraryCategoryFilterStorage.uncategorizedRaw
                showCategoryPicker = false
            }
            ForEach(sortedCategoriesAlphabetically, id: \.name) { cat in
                let label = CategoryDisplayFormatter.displayName(cat.name)
                filterPopoverRow(title: label, selected: filterCategoryRaw == cat.name) {
                    filterCategoryRaw = cat.name
                    showCategoryPicker = false
                }
            }
        }
        .frame(minWidth: 240)
        .padding(.vertical, 6)
    }

    private func filterPopoverRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer(minLength: 12)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var kindLabel: String {
        switch selectedKind {
        case .none: return "All"
        case .web: return "Web"
        case .media: return "Media"
        case .note: return "Notes"
        }
    }

    private var statusLabel: String {
        switch selectedStatus {
        case .none: return "All"
        case .new: return "New"
        case .read: return "Read"
        case .filed: return "Filed"
        }
    }

    private var categoryLabel: String {
        if filterCategoryRaw.isEmpty { return "All" }
        if filterCategoryRaw == LibraryCategoryFilterStorage.uncategorizedRaw { return "Uncategorized" }
        return CategoryDisplayFormatter.displayName(filterCategoryRaw)
    }
}

/// Capsule containing only the displayed value + chevron (labels live above in ``LibraryFilterBar``).
private struct FilterValueCapsule: View {
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.textPrimary)
                .phathomToolbarTextLabel()
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
}

#Preview("Default width") {
    struct Binder: View {
        @State private var kind: ContentKind?
        @State private var status: ReadStatus?
        @State private var categoryRaw = ""

        var body: some View {
            LibraryFilterBar(
                selectedKind: $kind,
                selectedStatus: $status,
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
        @State private var kind: ContentKind?
        @State private var status: ReadStatus?
        @State private var categoryRaw = ""

        var body: some View {
            LibraryFilterBar(
                selectedKind: $kind,
                selectedStatus: $status,
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
