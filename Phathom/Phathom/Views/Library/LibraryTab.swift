import SwiftData
import SwiftUI

struct LibraryTab: View {
    @Binding var deepLinkItemID: UUID?

    @Query(sort: \ContentItem.createdAt, order: .reverse)
    private var items: [ContentItem]

    @State private var filterKind: ContentKind?
    @State private var searchTapped = false
    @State private var navPath = NavigationPath()

    init(deepLinkItemID: Binding<UUID?> = .constant(nil)) {
        _deepLinkItemID = deepLinkItemID
    }

    private var filteredItems: [ContentItem] {
        guard let filterKind else { return items }
        return items.filter { $0.kind == filterKind }
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
                        Text("No items yet")
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        searchTapped = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
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
            .alert("Search", isPresented: $searchTapped) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Search is not available in this build.")
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
