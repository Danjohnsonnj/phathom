import PhathomCore
import SwiftData
import SwiftUI

struct NotebookTab: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Highlight.createdAt, order: .reverse)
    private var highlights: [Highlight]

    @Query(
        filter: #Predicate<ContentItem> { !$0.isArchived },
        sort: \.createdAt,
        order: .reverse
    )
    private var activeItems: [ContentItem]

    @Query(sort: \PhathomCore.Category.name, order: .forward)
    private var categories: [PhathomCore.Category]

    @AppStorage(NotebookFilterStorage.kindKey) private var filterKindRaw: String = ""
    @AppStorage(NotebookFilterStorage.statusKey) private var filterStatusRaw: String = ""
    @AppStorage(NotebookFilterStorage.categoryKey) private var filterCategoryRaw: String = ""
    @AppStorage(NotebookExpansionStorage.expandedIDsKey) private var expandedItemIDsRaw: String = ""

    @State private var navPath = NavigationPath()
    @State private var noteEditHighlight: Highlight?
    @State private var contentRevision = 0

    private var sortedCategoryNames: [String] {
        categories
            .sorted {
                CategoryDisplayFormatter.displayName($0.name).localizedCaseInsensitiveCompare(
                    CategoryDisplayFormatter.displayName($1.name)
                ) == .orderedAscending
            }
            .map(\.name)
    }

    private var unfilteredGroups: [NotebookHighlightsQuery.ItemGroup] {
        _ = contentRevision
        return NotebookHighlightsQuery.groups(from: highlights)
    }

    private var filteredGroups: [NotebookHighlightsQuery.ItemGroup] {
        _ = contentRevision
        return NotebookHighlightsQuery.groups(
            from: highlights,
            filterKinds: LibraryFilterCodec.decodeKinds(filterKindRaw),
            filterStatuses: LibraryFilterCodec.decodeStatuses(filterStatusRaw),
            filterCategories: LibraryFilterCodec.decodeCategories(filterCategoryRaw)
        )
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                notebookScrollChrome

                if filteredGroups.isEmpty {
                    if unfilteredGroups.isEmpty {
                        trueEmptyState
                    } else {
                        filterEmptyState
                    }
                } else {
                    ForEach(filteredGroups) { group in
                        NotebookItemGroup(
                            item: group.item,
                            highlights: group.highlights,
                            isExpanded: isNotebookItemExpanded(group.id),
                            showsBottomGroupHairline: group.id != filteredGroups.last?.id,
                            onHeaderTap: { navPath.append(group.item.id) },
                            onToggleExpand: { toggleNotebookItemExpanded(group.id) },
                            onHighlightTap: { noteEditHighlight = $0 }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)
            .background(AppPalette.background)
            .navigationDestination(for: UUID.self) { id in
                if let item = activeItems.first(where: { $0.id == id }) {
                    DetailView(item: item) { selectedID in
                        if !navPath.isEmpty { navPath.removeLast() }
                        navPath.append(selectedID)
                    }
                } else {
                    Text("This item is not in your library.")
                        .appTypography(.zoneSubtitle)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .phathomHideNavigationBar()
        }
        .onAppear {
            sanitizeCategoryFilterIfNeeded()
        }
        .onChange(of: sortedCategoryNames) { _, _ in
            sanitizeCategoryFilterIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomLibraryContentDidChange)) { _ in
            contentRevision &+= 1
        }
        .sheet(item: $noteEditHighlight) { highlight in
            HighlightNoteEditSheet(
                highlight: highlight,
                modelContext: modelContext,
                onDismiss: { noteEditHighlight = nil }
            )
        }
    }

    private func sanitizeCategoryFilterIfNeeded() {
        let sanitized = LibraryFilterCodec.sanitizeCategoryRaw(filterCategoryRaw, validNames: sortedCategoryNames)
        if sanitized != filterCategoryRaw {
            filterCategoryRaw = sanitized
        }
    }

    private func isNotebookItemExpanded(_ id: UUID) -> Bool {
        NotebookExpansionStorage.decodeExpandedIDs(expandedItemIDsRaw).contains(id)
    }

    private func toggleNotebookItemExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            var ids = NotebookExpansionStorage.decodeExpandedIDs(expandedItemIDsRaw)
            if ids.contains(id) {
                ids.remove(id)
            } else {
                ids.insert(id)
            }
            expandedItemIDsRaw = NotebookExpansionStorage.encodeExpandedIDs(ids)
        }
    }

    private var notebookScrollChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialScreenTitle(title: "Notebook")
            LibraryFilterBar(
                filterKindRaw: $filterKindRaw,
                filterStatusRaw: $filterStatusRaw,
                filterCategoryRaw: $filterCategoryRaw,
                categories: categories
            )
            .padding(.bottom, AppSpacing.filterBarBottom)
        }
        .textCase(nil)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var trueEmptyState: some View {
        EditorialTwoTierEmptyState(
            title: "No highlights yet",
            hint: "Highlight text in an article's Source view on Detail."
        )
        .padding(.top, AppSpacing.notebookGroupHeaderTop)
        .padding(.bottom, 24)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var filterEmptyState: some View {
        EditorialTwoTierEmptyState(
            title: "No highlights match these filters",
            hint: "Try changing Type, Status, or Category."
        )
        .padding(.top, AppSpacing.notebookGroupHeaderTop)
        .padding(.bottom, 24)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    NotebookTab()
        .modelContainer(PreviewModel.makeContainer())
}
