import PhathomCore
import SwiftUI

struct ChatTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EditorialScreenTitle(title: "Chat")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deep Dive is coming soon")
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(-0.34)
                            .foregroundStyle(AppPalette.textPrimary)
                        Text("Conversational search over your library, powered on device.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppPalette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)
            .background(AppPalette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
