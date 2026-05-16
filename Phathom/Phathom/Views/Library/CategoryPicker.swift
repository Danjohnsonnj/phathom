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
            List {
                Button {
                    complete(nil)
                } label: {
                    Text("Uncategorized")
                        .foregroundStyle(AppPalette.textPrimary)
                }

                if !sortedCategoriesExceptUncategorizedRows.isEmpty {
                    Section("Categories") {
                        ForEach(sortedCategoriesExceptUncategorizedRows, id: \.name) { cat in
                            Button {
                                complete(cat)
                            } label: {
                                Text(CategoryDisplayFormatter.displayName(cat.name))
                                    .foregroundStyle(AppPalette.textPrimary)
                            }
                        }
                    }
                }

                Section("New category") {
                    TextField("Name", text: $newDraft)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(AppPalette.textPrimary)

                    Button {
                        guard let norm = CategoryDisplayFormatter.normalize(newDraft) else { return }
                        complete(findOrInsertCategory(normalizedName: norm))
                    } label: {
                        Text("Create and use")
                            .foregroundStyle(AppPalette.accent)
                    }
                    .disabled(CategoryDisplayFormatter.normalize(newDraft) == nil)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if toolbarCancelPassesSelection {
                            complete(nil)
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
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
