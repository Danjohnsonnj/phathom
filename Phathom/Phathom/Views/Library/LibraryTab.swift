import SwiftData
import SwiftUI

struct LibraryTab: View {
    @Query(sort: \ContentItem.createdAt, order: .reverse)
    private var items: [ContentItem]

    @State private var filterKind: ContentKind?
    @State private var searchTapped = false

    private var filteredItems: [ContentItem] {
        guard let filterKind else { return items }
        return items.filter { $0.kind == filterKind }
    }

    var body: some View {
        NavigationStack {
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
                                NavigationLink {
                                    DetailView(item: item)
                                } label: {
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
    }
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
