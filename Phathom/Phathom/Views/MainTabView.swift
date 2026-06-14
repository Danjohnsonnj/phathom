import PhathomCore
import CoreSpotlight
import SwiftData
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var libraryDeepLinkID: UUID?

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

            NotebookTab()
                .tabItem {
                    Label("Notebook", systemImage: "highlighter")
                }
                .tag(1)

            FocusTab(onNavigateToLibrary: { selectedTab = 0 })
                .tabItem {
                    Label("Focus", systemImage: "scope")
                }
                .tag(2)

            AddNewTab(onNavigateToLibrary: { selectedTab = 0 })
                .tabItem {
                    Label("Add new", systemImage: "plus")
                }
                .tag(3)
        }
        .tint(AppPalette.accent)
        .preferredColorScheme(.dark)
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
        .archiveUndoSnackbar(isVisible: selectedTab == 0) {
            selectedTab = 0
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewModel.makeContainer())
}
