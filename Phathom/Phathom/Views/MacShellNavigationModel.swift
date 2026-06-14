#if os(macOS)
import Foundation
import Observation

@Observable
@MainActor
final class MacShellNavigationModel {
    var selection: MacNavigationSelection = .library
    var libraryDeepLinkID: UUID?

    func navigateToLibrary(deepLinkItemID: UUID? = nil) {
        if let deepLinkItemID {
            libraryDeepLinkID = deepLinkItemID
        }
        selection = .library
    }
}
#endif
