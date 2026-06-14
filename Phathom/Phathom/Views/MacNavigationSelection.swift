import Foundation
import SwiftUI

/// Sidebar selection for Mac shell (Phase 3). Defined in Phase 1 for shared navigation callbacks.
enum MacNavigationSelection: Hashable, CaseIterable {
    case library
    case notebook
    case focus
    case addNew
    case settings

    var title: String {
        switch self {
        case .library: "Library"
        case .notebook: "Notebook"
        case .focus: "Focus"
        case .addNew: "Add New"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .notebook: "note.text"
        case .focus: "scope"
        case .addNew: "plus.circle"
        case .settings: "gearshape"
        }
    }

    #if os(macOS)
    /// ⌘1…⌘5 sidebar shortcuts (macOS shell menu).
    var menuKey: KeyEquivalent {
        switch self {
        case .library: "1"
        case .notebook: "2"
        case .focus: "3"
        case .addNew: "4"
        case .settings: "5"
        }
    }
    #endif
}
