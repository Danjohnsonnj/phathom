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

    private static let horizontalPadding: CGFloat = 16

    private var itemGroups: [NotebookHighlightsQuery.ItemGroup] {
        _ = contentRevision
        return NotebookHighlightsQuery.groups(from: highlights)
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(alignment: .leading, spacing: 0) {
                notebookChromeAboveList

                List {
                    if itemGroups.isEmpty {
                        emptyState
                    } else {
                        ForEach(itemGroups) { group in
                            NotebookItemGroup(
                                item: group.item,
                                highlights: group.highlights,
                                onHeaderTap: { navPath.append(group.item.id) },
                                onHighlightTap: { noteEditHighlight = $0 }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: Self.horizontalPadding, bottom: 20, trailing: Self.horizontalPadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppPalette.background)
            }
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
            .navigationTitle("Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Phathom")
                        .font(.headline)
                        .foregroundStyle(AppPalette.textPrimary)
                }
            }
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
            .presentationDetents([.medium, .large])
        }
    }

    private var notebookChromeAboveList: some View {
        Text("Notebook")
            .font(.largeTitle.bold())
            .foregroundStyle(AppPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.bottom, 4)
            .background(AppPalette.background)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No highlights yet")
                .font(.subheadline)
                .foregroundStyle(AppPalette.textPrimary)
            Text("Highlight text in an article's Source view on Detail.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 48)
        .listRowInsets(EdgeInsets(top: 0, leading: Self.horizontalPadding, bottom: 0, trailing: Self.horizontalPadding))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    NotebookTab()
        .modelContainer(PreviewModel.makeContainer())
}
