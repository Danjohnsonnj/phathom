import PhathomCore
import SwiftData
import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext

    /// Caps in-memory list size; 48h retention rarely exceeds this on device.
    private static let archivedFetchLimit = 300

    @Query private var archivedItems: [ContentItem]

    @State private var itemIDPendingDelete: UUID?
    @State private var confirmDeleteAll = false

    init() {
        var descriptor = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { $0.isArchived == true },
            sortBy: [SortDescriptor(\.archivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.archivedFetchLimit
        _archivedItems = Query(descriptor)
    }

    private var isCapped: Bool {
        archivedItems.count == Self.archivedFetchLimit
    }

    var body: some View {
        Group {
            if archivedItems.isEmpty {
                ContentUnavailableView(
                    "Nothing in Recently Deleted",
                    systemImage: "trash",
                    description: Text("Archived items appear here for 48 hours before they are removed permanently.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(archivedItems, id: \.id) { item in
                            NavigationLink {
                                DetailView(item: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ContentCardRow(item: item, chrome: .plain)
                                    if let at = item.archivedAt {
                                        Text(ArchiveRetention.timeUntilPermanentDeletion(from: at))
                                            .font(.caption)
                                            .foregroundStyle(AppPalette.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens full item. You can restore to the Library from the detail screen.")
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Restore") {
                                    ArchiveRetention.restore(item)
                                    try? modelContext.save()
                                    LibraryContentChangeNotifier.postLibraryContentDidChange()
                                    NotificationCenter.default.post(name: .phathomArchivedItemsDidChange, object: nil)
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    itemIDPendingDelete = item.id
                                }
                            }
                        }

                        if isCapped {
                            Text("Showing the \(Self.archivedFetchLimit) most recently deleted items.")
                                .font(.caption)
                                .foregroundStyle(AppPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(AppPalette.background)
            }
        }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .foregroundStyle(AppPalette.textPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete All") {
                    confirmDeleteAll = true
                }
                .disabled(archivedItems.isEmpty)
                .foregroundStyle(archivedItems.isEmpty ? AppPalette.textTertiary : .red)
            }
        }
        .alert(
            "Delete permanently?",
            isPresented: Binding(
                get: { itemIDPendingDelete != nil },
                set: { if !$0 { itemIDPendingDelete = nil } }
            )
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let id = itemIDPendingDelete {
                    let fd = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == id })
                    if let found = try? modelContext.fetch(fd).first {
                        modelContext.delete(found)
                        try? modelContext.save()
                        LibraryContentChangeNotifier.postLibraryContentDidChange()
                        NotificationCenter.default.post(name: .phathomArchivedItemsDidChange, object: nil)
                    }
                }
                itemIDPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemIDPendingDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Delete all items in Recently Deleted?",
            isPresented: $confirmDeleteAll
        ) {
            Button("Delete All", role: .destructive) {
                deleteAllArchivedItems()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every archived item will be removed immediately.")
        }
    }

    private func deleteAllArchivedItems() {
        let fd = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { $0.isArchived == true }
        )
        guard let all = try? modelContext.fetch(fd) else { return }
        for item in all {
            modelContext.delete(item)
        }
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        NotificationCenter.default.post(name: .phathomArchivedItemsDidChange, object: nil)
    }
}

#Preview {
    NavigationStack {
        RecentlyDeletedView()
    }
    .modelContainer(PreviewModel.makeContainer())
}
