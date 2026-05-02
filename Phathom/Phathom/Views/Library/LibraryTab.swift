import PhathomCore
import SwiftData
import SwiftUI

struct LibraryTab: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var deepLinkItemID: UUID?

    @Query(
        filter: #Predicate<ContentItem> { !$0.isArchived },
        sort: \.createdAt,
        order: .reverse
    )
    private var items: [ContentItem]

    @State private var filterKind: ContentKind?
    @State private var searchText = ""
    @State private var navPath = NavigationPath()

    init(deepLinkItemID: Binding<UUID?> = .constant(nil)) {
        _deepLinkItemID = deepLinkItemID
    }

    private var filteredItems: [ContentItem] {
        let kindFiltered: [ContentItem]
        if let filterKind {
            kindFiltered = items.filter { $0.kind == filterKind }
        } else {
            kindFiltered = items
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return kindFiltered }

        return kindFiltered.filter { item in
            let titleMatch = item.displayTitle.lowercased().contains(query)
            let rawTextMatch = (item.rawText ?? "").lowercased().contains(query)
            let hostMatch = (item.displayHost ?? "").lowercased().contains(query)
            let urlMatch = (item.originalURL?.absoluteString ?? "").lowercased().contains(query)
            let mediaMatch = (item.mediaDescription ?? "").lowercased().contains(query)
            let tagsMatch = item.tags.map(\.name).joined(separator: " ").lowercased().contains(query)
            return titleMatch || rawTextMatch || hostMatch || urlMatch || mediaMatch || tagsMatch
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Recent items")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    FilterPills(selected: $filterKind)

                    if filteredItems.isEmpty {
                        Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No items yet" : "No matches")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems, id: \.id) { item in
                                NavigationLink(value: item.id) {
                                    ContentCardRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        archiveFromLibrary(item: item)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppPalette.background)
            .navigationTitle("Recent Items")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let item = items.first(where: { $0.id == id }) {
                    DetailView(item: item)
                } else {
                    Text("This item is not in your library.")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .searchable(text: $searchText, prompt: "Search title, tags, source text")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Phathom")
                        .font(.headline)
                        .foregroundStyle(AppPalette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsContent()
                            .navigationTitle("Settings")
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .onChange(of: deepLinkItemID) { _, newValue in
            guard let id = newValue else { return }
            navPath.append(id)
            deepLinkItemID = nil
        }
    }

    private func archiveFromLibrary(item: ContentItem) {
        ArchiveRetention.archive(item)
        try? modelContext.save()
        NotificationCenter.default.post(
            name: .phathomDidArchiveItem,
            object: nil,
            userInfo: ["itemID": item.id, "switchToLibrary": true]
        )
    }
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
