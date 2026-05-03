import PhathomCore
import CoreSpotlight
import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab = 0
    @State private var libraryDeepLinkID: UUID?

    @State private var undoArchiveItemID: UUID?
    @State private var undoArchiveTask: Task<Void, Never>?

    init() {
        AppAppearance.configureIfNeeded()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryTab(deepLinkItemID: $libraryDeepLinkID)
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle.angled")
                }
                .tag(0)

            ChatTab()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(1)

            AddNewTab(selectedTab: $selectedTab)
                .tabItem {
                    Label("Add new", systemImage: "plus")
                }
                .tag(2)
        }
        .tint(AppPalette.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            ArchiveRetention.purgeExpired(in: modelContext)
            ModelManager.validateSelection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ArchiveRetention.purgeExpired(in: modelContext)
                ModelManager.validateSelection()
                BackgroundPipeline.scheduleForegroundDrain()
            } else if phase == .background || phase == .inactive {
                BackgroundPipeline.scheduleAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPhathomItem)) { note in
            guard let raw = note.userInfo?["itemID"] as? String,
                  let id = UUID(uuidString: raw) else { return }
            libraryDeepLinkID = id
            selectedTab = 0
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let id = UUID(uuidString: raw) {
                libraryDeepLinkID = id
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomDidArchiveItem)) { note in
            guard let id = note.userInfo?["itemID"] as? UUID else { return }
            // Undo snackbar is inset only on Library (`selectedTab == 0`). Today only Library / detail-back archive posts this; `switchToLibrary` gates future non-Library posters.
            let switchToLibrary = note.userInfo?["switchToLibrary"] as? Bool ?? true
            if switchToLibrary, selectedTab != 0 {
                selectedTab = 0
            }
            startArchiveUndo(for: id)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedTab == 0, undoArchiveItemID != nil {
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
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.textTertiary.opacity(0.35), lineWidth: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
    }

    private func startArchiveUndo(for id: UUID) {
        undoArchiveItemID = id
        undoArchiveTask?.cancel()
        undoArchiveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
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

#Preview {
    MainTabView()
        .modelContainer(PreviewModel.makeContainer())
}
