import SwiftUI

extension View {
    @ViewBuilder
    func phathomInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func phathomAutocapitalizationNever() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func phathomAutocapitalizationWords() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    @ViewBuilder
    func phathomURLKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.URL)
        #else
        self
        #endif
    }

    @ViewBuilder
    func phathomFullScreenPhotoCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
        sheet(item: item, onDismiss: onDismiss, content: content)
        #endif
    }
}

#if os(iOS)
extension ToolbarContent {
    @ToolbarContentBuilder
    func phathomSharedToolbarBackgroundHidden() -> some ToolbarContent {
        sharedBackgroundVisibility(.hidden)
    }
}
#else
extension ToolbarContent {
    @ToolbarContentBuilder
    func phathomSharedToolbarBackgroundHidden() -> some ToolbarContent {
        self
    }
}
#endif

enum PhathomToolbarPlacement {
    static var trailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    static var leading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }
}

enum PhathomEditMode: Equatable {
    case inactive
    case active

    var isActive: Bool { self == .active }

    mutating func toggle() {
        self = isActive ? .inactive : .active
    }
}

#if os(iOS)
extension PhathomEditMode {
    var swiftUIValue: EditMode { isActive ? .active : .inactive }

    init(_ value: EditMode) {
        self = value == .active ? .active : .inactive
    }
}

extension View {
    func phathomEditMode(_ binding: Binding<PhathomEditMode>) -> some View {
        environment(
            \.editMode,
            Binding(
                get: { binding.wrappedValue.swiftUIValue },
                set: { binding.wrappedValue = PhathomEditMode($0) }
            )
        )
    }

    @ViewBuilder
    func phathomHideNavigationBar() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }
}
#else
extension View {
    func phathomEditMode(_ binding: Binding<PhathomEditMode>) -> some View { self }

    @ViewBuilder
    func phathomHideNavigationBar() -> some View { self }
}
#endif
