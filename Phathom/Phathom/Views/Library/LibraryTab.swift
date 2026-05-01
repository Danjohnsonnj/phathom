import SwiftData
import SwiftUI

struct LibraryTab: View {
    @Binding var deepLinkItemID: UUID?

    @Query(sort: \ContentItem.createdAt, order: .reverse)
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
            let titleMatch = (item.title ?? "").lowercased().contains(query)
            let rawTextMatch = (item.rawText ?? "").lowercased().contains(query)
            let hostMatch = (item.displayHost ?? "").lowercased().contains(query)
            let mediaMatch = (item.mediaDescription ?? "").lowercased().contains(query)
            let tagsMatch = item.tags.map(\.name).joined(separator: " ").lowercased().contains(query)
            return titleMatch || rawTextMatch || hostMatch || mediaMatch || tagsMatch
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
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
