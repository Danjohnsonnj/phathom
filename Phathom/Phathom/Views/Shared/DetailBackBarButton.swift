import SwiftUI

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

/// Trailing Detail share — flat secondary icon (mock `detail-nav-share`).
struct DetailShareBarButton: View {
    let shareURL: URL?
    let fallbackTitle: String

    var body: some View {
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
        .sharedBackgroundVisibility(.hidden)
    }
}

/// Leading toolbar slot — prefer ``DetailPushNavBar`` + `.safeAreaInset` for 22pt alignment.
struct DetailBackBarToolbarItem: ToolbarContent {
    var action: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            DetailBackBarButton(action: action)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

/// Trailing toolbar slot — prefer ``DetailPushNavBar`` + ``DetailShareBarButton`` for 22pt alignment.
struct DetailShareToolbarItem: ToolbarContent {
    let shareURL: URL?
    let fallbackTitle: String

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            DetailShareBarButton(shareURL: shareURL, fallbackTitle: fallbackTitle)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

#Preview("Push nav chrome") {
    NavigationStack {
        ScrollView {
            Text("Title block aligns with chevron leading edge")
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            DetailPushNavBar {
                DetailShareBarButton(shareURL: nil, fallbackTitle: "Example")
            }
        }
    }
}
