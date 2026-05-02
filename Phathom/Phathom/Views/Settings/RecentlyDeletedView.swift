import PhathomCore
import SwiftData
import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<ContentItem> { $0.isArchived == true },
        sort: [SortDescriptor(\.archivedAt, order: .reverse)]
    )
    private var archivedItems: [ContentItem]

    @State private var itemIDPendingDelete: UUID?
    @State private var confirmDeleteAll = false

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
                List {
                    ForEach(archivedItems, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            ContentCardRow(item: item)
                            if let at = item.archivedAt {
                                Text(ArchiveRetention.timeUntilPermanentDeletion(from: at))
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.textSecondary)
                            }
                        }
                        .listRowBackground(AppPalette.surface)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button("Restore") {
                                ArchiveRetention.restore(item)
                                try? modelContext.save()
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                itemIDPendingDelete = item.id
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
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
                let snapshot = archivedItems
                for item in snapshot {
                    modelContext.delete(item)
                }
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every archived item will be removed immediately.")
        }
    }
}

#Preview {
    NavigationStack {
        RecentlyDeletedView()
    }
    .modelContainer(PreviewModel.makeContainer())
}
