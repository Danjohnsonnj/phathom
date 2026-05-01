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

    @State private var undoArchiveItemID: UUID?
    @State private var undoArchiveTask: Task<Void, Never>?

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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if undoArchiveItemID != nil {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Archived. You can restore it from Recently Deleted within 2 days.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Button("Undo") {
                            performUndoArchive()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppPalette.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }
        }
        .onChange(of: deepLinkItemID) { _, newValue in
            guard let id = newValue else { return }
            navPath.append(id)
            deepLinkItemID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomDidArchiveItem)) { note in
            guard let id = note.userInfo?["itemID"] as? UUID else { return }
            startArchiveUndo(for: id)
        }
    }

    private func archiveFromLibrary(item: ContentItem) {
        ArchiveRetention.archive(item)
        try? modelContext.save()
        NotificationCenter.default.post(
            name: .phathomDidArchiveItem,
            object: nil,
            userInfo: ["itemID": item.id]
        )
    }

    private func startArchiveUndo(for id: UUID) {
        undoArchiveItemID = id
        undoArchiveTask?.cancel()
        undoArchiveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            undoArchiveItemID = nil
        }
    }

    private func performUndoArchive() {
        undoArchiveTask?.cancel()
        guard let id = undoArchiveItemID else { return }
        let fd = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == id })
        if let item = try? modelContext.fetch(fd).first {
            ArchiveRetention.restore(item)
            try? modelContext.save()
        }
        undoArchiveItemID = nil
    }
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
