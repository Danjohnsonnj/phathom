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

    @State private var navPath = NavigationPath()
    @State private var noteEditHighlight: Highlight?
    @State private var contentRevision = 0

    private var itemGroups: [NotebookHighlightsQuery.ItemGroup] {
        _ = contentRevision
        return NotebookHighlightsQuery.groups(from: highlights)
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                notebookScrollChrome

                if itemGroups.isEmpty {
                    emptyState
                } else {
                    ForEach(itemGroups) { group in
                        NotebookItemGroup(
                            item: group.item,
                            highlights: group.highlights,
                            showsBottomGroupHairline: group.id != itemGroups.last?.id,
                            onHeaderTap: { navPath.append(group.item.id) },
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
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

    private var notebookScrollChrome: some View {
        EditorialScreenTitle(title: "Notebook")
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No highlights yet")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.34)
                .foregroundStyle(AppPalette.textPrimary)
            Text("Highlight text in an article's Source view on Detail.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 280, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
