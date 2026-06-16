import PhathomCore
import SwiftData
import SwiftUI

/// Present after moving item(s) to **Filed** or for Detail category edits. `nil` category = Uncategorized when applied via list rows.
///
/// Fully qualifies ``PhathomCore/Category``: SwiftUI also defines `Category` on newer SDKs.
///
/// - When ``toolbarCancelPassesSelection`` is `false`, toolbar **Cancel** only dismisses (no `onPick`). Filing flows keep default `true` so Cancel matches **Uncategorized**.
struct CategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PhathomCore.Category.name, order: .forward)
    private var categories: [PhathomCore.Category]

    /// When `false`, toolbar Cancel dismisses without calling ``onPick`` (Detail edit); when `true`, Cancel applies `nil` like the Uncategorized row (filing).
    var toolbarCancelPassesSelection: Bool = true

    var navigationTitle: String = "Filed category"

    var onPick: (PhathomCore.Category?) -> Void

    @State private var newDraft = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Button {
                        complete(nil)
                    } label: {
                        categoryRowLabel("Uncategorized")
                    }
                    .buttonStyle(.plain)

                    if !sortedCategoriesExceptUncategorizedRows.isEmpty {
                        pickerSectionHeader("Categories")
                        ForEach(Array(sortedCategoriesExceptUncategorizedRows.enumerated()), id: \.element.name) { index, cat in
                            Button {
                                complete(cat)
                            } label: {
                                categoryRowLabel(CategoryDisplayFormatter.displayName(cat.name))
                            }
                            .buttonStyle(.plain)
                            if index < sortedCategoriesExceptUncategorizedRows.count - 1 {
                                categoryRowHairline
                            }
                        }
                    }

                    pickerSectionHeader("New category")
                    TextField("Name", text: $newDraft)
                        .appTypography(.body)
                        .phathomAutocapitalizationWords()
                        .foregroundStyle(AppPalette.textPrimary)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.vertical, 12)

                    Button {
                        guard let norm = CategoryDisplayFormatter.normalize(newDraft) else { return }
                        complete(findOrInsertCategory(normalizedName: norm))
                    } label: {
                        Text("Create and use")
                            .appTypography(.body)
                            .foregroundStyle(AppPalette.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(CategoryDisplayFormatter.normalize(newDraft) == nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .phathomSheetHeightMeasurable()
            }
            .background(AppPalette.background)
            .navigationTitle(navigationTitle)
            .phathomInlineNavigationTitle()
            .toolbar {
                FlatToolbarTextItem(
                    title: "Cancel",
                    placement: .cancellationAction,
                    foreground: AppPalette.accent
                ) {
                    if toolbarCancelPassesSelection {
                        complete(nil)
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .phathomSheetPresentation()
    }

    private func pickerSectionHeader(_ title: String) -> some View {
        Text(title)
            .appTypography(.subsectionHeader)
            .foregroundStyle(AppPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func categoryRowLabel(_ title: String) -> some View {
        Text(title)
            .appTypography(.body)
            .foregroundStyle(AppPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 12)
    }

    private var categoryRowHairline: some View {
        Rectangle()
            .fill(AppPalette.hairline)
            .frame(height: 1)
            .padding(.leading, AppSpacing.screenHorizontal)
    }

    private var sortedCategoriesExceptUncategorizedRows: [PhathomCore.Category] {
        categories.sorted {
            CategoryDisplayFormatter.displayName($0.name).localizedCaseInsensitiveCompare(
                CategoryDisplayFormatter.displayName($1.name)
            ) == .orderedAscending
        }
    }

    private func complete(_ category: PhathomCore.Category?) {
        onPick(category)
        dismiss()
    }

    private func findOrInsertCategory(normalizedName: String) -> PhathomCore.Category {
        let descriptor = FetchDescriptor<PhathomCore.Category>(
            predicate: #Predicate<PhathomCore.Category> { $0.name == normalizedName }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let created = PhathomCore.Category(name: normalizedName)
        modelContext.insert(created)
        return created
    }
}
