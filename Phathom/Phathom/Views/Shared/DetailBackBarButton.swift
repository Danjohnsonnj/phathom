import SwiftUI

/// Detail / Settings push back affordance — accent chevron only (mock `detail-nav-back` parity).
///
/// **Not** a liquid-glass toolbar button: use ``DetailBackBarToolbarItem`` in `.toolbar` so
/// iOS 26 does not apply a shared glass capsule behind the chevron.
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
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppPalette.accent)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Back")
    }
}

/// Leading toolbar slot for push back — flat chevron, no glass background (iOS 26+).
struct DetailBackBarToolbarItem: ToolbarContent {
    var action: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            DetailBackBarButton(action: action)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

/// Trailing Detail share — flat secondary icon (mock `detail-nav-share`), no glass capsule.
struct DetailShareToolbarItem: ToolbarContent {
    let shareURL: URL?
    let fallbackTitle: String

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
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
        .sharedBackgroundVisibility(.hidden)
    }

    private var shareLabel: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(AppPalette.textSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Share")
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                DetailBackBarToolbarItem()
            }
    }
}
