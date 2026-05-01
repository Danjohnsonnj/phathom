import CoreSpotlight
import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase

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

            ChatTab()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(1)

            AddNewTab()
                .tabItem {
                    Label("Add new", systemImage: "plus")
                }
                .tag(2)
        }
        .tint(AppPalette.accent)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
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
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewModel.makeContainer())
}
