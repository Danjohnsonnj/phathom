import SwiftUI
import UIKit

// MARK: - Sheet content-fit sizing (design-tokens §6.1)

private enum PhathomSheetMetrics {
    static let navBarAllowance: CGFloat = 56
    static let minSheetHeight: CGFloat = 200
    static var maxSheetHeight: CGFloat {
        UIScreen.main.bounds.height * 0.92
    }
}

private struct SheetContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Reports intrinsic height of the measure stack (VStack / LazyVStack) for sheet detents.
    func phathomSheetHeightMeasurable() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SheetContentHeightKey.self, value: geometry.size.height)
            }
        }
    }

    /// Content-fit sheet: opens at measured height (capped), scrolls inside when overflow; user may drag to `.large`.
    func phathomSheetPresentation() -> some View {
        modifier(PhathomSheetPresentationModifier())
    }
}

private struct PhathomSheetPresentationModifier: ViewModifier {
    @State private var contentHeight = PhathomSheetMetrics.minSheetHeight
    @State private var selectedDetent: PresentationDetent = .height(PhathomSheetMetrics.minSheetHeight)
    @State private var userExpandedToLarge = false

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(SheetContentHeightKey.self) { reported in
                guard reported > 0 else { return }
                let capped = min(
                    max(reported + PhathomSheetMetrics.navBarAllowance, PhathomSheetMetrics.minSheetHeight),
                    PhathomSheetMetrics.maxSheetHeight
                )
                contentHeight = capped
                guard !userExpandedToLarge else { return }
                selectedDetent = .height(capped)
            }
            .presentationDetents([.height(contentHeight), .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .onChange(of: selectedDetent) { _, newDetent in
                if newDetent == .large {
                    userExpandedToLarge = true
                }
            }
    }
}
