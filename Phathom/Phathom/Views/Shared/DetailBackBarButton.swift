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
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppPalette.accent)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Back")
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DetailBackBarButton()
                }
            }
    }
}
