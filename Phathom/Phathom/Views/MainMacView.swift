#if os(macOS)
import CoreSpotlight
import PhathomCore
import SwiftData
import SwiftUI

struct MainMacView: View {
    @Environment(MacShellNavigationModel.self) private var navigation

    init() {
        AppAppearance.configureIfNeeded()
    }

    private var libraryDeepLinkBinding: Binding<UUID?> {
        Binding(
            get: { navigation.libraryDeepLinkID },
            set: { navigation.libraryDeepLinkID = $0 }
        )
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            List(MacNavigationSelection.allCases, id: \.self, selection: $navigation.selection) { section in
                Label(section.title, systemImage: section.systemImage)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Phathom")
        } detail: {
            detailContent
        }
        .tint(AppPalette.accent)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .openPhathomItem)) { note in
            guard let raw = note.userInfo?["itemID"] as? String,
                  let id = UUID(uuidString: raw) else { return }
            navigation.navigateToLibrary(deepLinkItemID: id)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let id = UUID(uuidString: raw) {
                navigation.navigateToLibrary(deepLinkItemID: id)
            }
        }
        .archiveUndoSnackbar(isVisible: navigation.selection == .library) {
            navigation.navigateToLibrary()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch navigation.selection {
        case .library:
            LibraryTab(deepLinkItemID: libraryDeepLinkBinding)
        case .notebook:
            NotebookTab()
        case .focus:
            FocusTab(onNavigateToLibrary: { navigation.navigateToLibrary() })
        case .addNew:
            AddNewTab(onNavigateToLibrary: { navigation.navigateToLibrary() })
        case .settings:
            SettingsTab()
        }
    }
}

#Preview {
    MainMacView()
        .environment(MacShellNavigationModel())
        .modelContainer(PreviewModel.makeContainer())
}
#endif
