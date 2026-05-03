import PhathomCore
import SwiftData
import SwiftUI

struct LibraryTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var isModelHealthyForIndicator = false

    init(deepLinkItemID: Binding<UUID?> = .constant(nil)) {
        _deepLinkItemID = deepLinkItemID
    }

    private var emptyLibraryMessage: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No items yet" : "No matches"
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
            List {
                Section {
                    if filteredItems.isEmpty {
                        Text(emptyLibraryMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredItems, id: \.id) { item in
                            NavigationLink(value: item.id) {
                                ContentCardRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .navigationLinkIndicatorVisibility(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    archiveFromLibrary(item: item)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Library")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        FilterPills(selected: $filterKind)
                    }
                    .textCase(nil)
                    .padding(.bottom, 4)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppPalette.background)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let item = items.first(where: { $0.id == id }) {
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
                        Image(systemName: isModelHealthyForIndicator ? "gearshape.fill" : "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityValue(isModelHealthyForIndicator ? "AI model ready" : "AI model needs attention")
                }
            }
        }
        .onAppear {
            refreshModelIndicator()
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomModelAvailabilityDidChange)) { _ in
            refreshModelIndicator()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshModelIndicator()
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

    private func refreshModelIndicator() {
        ModelManager.validateSelection()
        let selection = ModelManager.selectionDisplayState()
        let hasReadySelection: Bool
        switch selection {
        case .ready:
            hasReadySelection = true
        case .noSelection, .missingFile:
            hasReadySelection = false
        }
        isModelHealthyForIndicator = hasReadySelection && !ModelManager.didLastLoadFail
    }
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
