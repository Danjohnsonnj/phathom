import SwiftUI

/// Horizontal rule interrupted by centered "AI ANALYSIS" label — separates reader content from AI synthesis.
struct DetailAIAnalysisDivider: View {
    private static let dividerHeight: CGFloat = 1

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(AppPalette.textSecondary)
                .frame(height: Self.dividerHeight)
                .frame(maxWidth: .infinity)
            Text("AI ANALYSIS")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppPalette.textSecondary)
                .tracking(0.5)
                .textCase(.uppercase)
                .fixedSize(horizontal: true, vertical: false)
            Capsule()
                .fill(AppPalette.textSecondary)
                .frame(height: Self.dividerHeight)
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI Analysis")
        .padding(.vertical, 12)
    }
}
