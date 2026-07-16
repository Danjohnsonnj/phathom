import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Detail / Settings push back affordance — accent chevron only (mock `detail-nav-back` parity).
struct DetailBackBarButton: View {
    @Environment(\.dismiss) private var dismiss

    var action: (() -> Void)?

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .regular))
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppPalette.accent)
        .accessibilityLabel("Back")
    }
}

/// Trailing Detail overflow — Share link + optional annotated markdown export.
struct DetailOverflowMenu: View {
    let shareURL: URL?
    let fallbackTitle: String
    let canExportMarkdown: Bool
    let onShareLink: () -> Void
    let onExportMarkdown: () -> Void

    var body: some View {
        Menu {
            #if os(macOS)
            if let shareURL {
                ShareLink(item: shareURL) {
                    Label("Share link", systemImage: "link")
                }
            } else {
                ShareLink(item: fallbackTitle) {
                    Label("Share link", systemImage: "link")
                }
            }
            #else
            Button(action: onShareLink) {
                Label("Share link", systemImage: "link")
            }
            #endif

            if canExportMarkdown {
                Button(action: onExportMarkdown) {
                    Label("Export markdown", systemImage: "doc.text")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppPalette.textSecondary)
                .padding(8)
                .accessibilityLabel("More")
        }
        .buttonStyle(.plain)
    }
}

/// Trailing Detail share — flat secondary icon (mock `detail-nav-share`). Prefer ``DetailOverflowMenu``.
struct DetailShareBarButton: View {
    let shareURL: URL?
    let fallbackTitle: String

    #if os(iOS)
    @State private var isPresentingShare = false
    #endif

    private var shareItems: [Any] {
        if let shareURL { return [shareURL] }
        return [fallbackTitle]
    }

    var body: some View {
        #if os(iOS)
        Button {
            isPresentingShare = true
        } label: {
            shareLabel
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresentingShare) {
            ShareActivityViewController(items: shareItems) {
                isPresentingShare = false
            }
            .ignoresSafeArea()
        }
        #else
        Group {
            if let shareURL {
                ShareLink(item: shareURL) {
                    shareLabel
                }
            } else {
                ShareLink(item: fallbackTitle) {
                    shareLabel
                }
            }
        }
        .buttonStyle(.plain)
        #endif
    }

    private var shareLabel: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(AppPalette.textSecondary)
            .padding(8)
            .accessibilityLabel("Share")
    }
}

/// Mock `.detail-nav` — **22pt** horizontal rhythm; back chevron aligns with scroll content inset.
struct DetailPushNavBar<Trailing: View>: View {
    var backAction: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    init(backAction: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.backAction = backAction
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            DetailBackBarButton(action: backAction)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.pushNavBarTop)
        .padding(.bottom, AppSpacing.pushNavBarBottom)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(AppPalette.background)
        .background(NavigationInteractivePopEnabler())
    }
}

extension DetailPushNavBar where Trailing == EmptyView {
    init(backAction: (() -> Void)? = nil) {
        self.backAction = backAction
        self.trailing = { EmptyView() }
    }
}

/// Flat accent/destructive toolbar label — no liquid-glass capsule (design-tokens §5.1 / §6).
struct FlatToolbarTextButton: View {
    let title: String
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appTypography(.body)
                .phathomToolbarTextLabel()
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
    }
}

/// Sheet/modal toolbar text action with hidden shared background (iOS 26 glass off).
struct FlatToolbarTextItem: ToolbarContent {
    let title: String
    let placement: ToolbarItemPlacement
    let foreground: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            FlatToolbarTextButton(title: title, foreground: foreground, action: action)
                .disabled(disabled)
        }
        .phathomSharedToolbarBackgroundHidden()
    }
}

/// Leading toolbar slot — prefer ``DetailPushNavBar`` + `.safeAreaInset` for 22pt alignment.
struct DetailBackBarToolbarItem: ToolbarContent {
    var action: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: PhathomToolbarPlacement.leading) {
            DetailBackBarButton(action: action)
        }
        .phathomSharedToolbarBackgroundHidden()
    }
}

/// Trailing toolbar slot — prefer ``DetailPushNavBar`` + ``DetailOverflowMenu`` for 22pt alignment.
struct DetailShareToolbarItem: ToolbarContent {
    let shareURL: URL?
    let fallbackTitle: String
    var canExportMarkdown: Bool = false
    var onShareLink: (() -> Void)?
    var onExportMarkdown: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: PhathomToolbarPlacement.trailing) {
            if let onShareLink, let onExportMarkdown {
                DetailOverflowMenu(
                    shareURL: shareURL,
                    fallbackTitle: fallbackTitle,
                    canExportMarkdown: canExportMarkdown,
                    onShareLink: onShareLink,
                    onExportMarkdown: onExportMarkdown
                )
            } else {
                DetailShareBarButton(shareURL: shareURL, fallbackTitle: fallbackTitle)
            }
        }
        .phathomSharedToolbarBackgroundHidden()
    }
}

#Preview("Push nav chrome") {
    NavigationStack {
        ScrollView {
            Text("Title block aligns with chevron leading edge")
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .phathomInlineNavigationTitle()
        .navigationBarBackButtonHidden(true)
        .phathomHideNavigationBar()
        .safeAreaInset(edge: .top, spacing: 0) {
            DetailPushNavBar {
                DetailOverflowMenu(
                    shareURL: nil,
                    fallbackTitle: "Example",
                    canExportMarkdown: true,
                    onShareLink: {},
                    onExportMarkdown: {}
                )
            }
        }
    }
}
