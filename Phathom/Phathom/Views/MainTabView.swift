import SwiftData
import SwiftUI

struct MainTabView: View {
    init() {
        AppAppearance.configureIfNeeded()
    }

    var body: some View {
        TabView {
            LibraryTab()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle.angled")
                }

            ChatTab()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            AddNewTab()
                .tabItem {
                    Label("Add new", systemImage: "plus")
                }
        }
        .tint(AppPalette.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewModel.makeContainer())
}
