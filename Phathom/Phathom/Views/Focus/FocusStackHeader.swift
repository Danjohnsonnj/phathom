import PhathomCore
import SwiftUI

struct FocusStackHeader: View {
    let activeCount: Int

    private var openCount: Int {
        max(FocusStackConstants.maxActiveEntries - activeCount, 0)
    }

    private var subline: String {
        let capacity = "\(activeCount) of \(FocusStackConstants.maxActiveEntries) · \(openCount) open"
        switch activeCount {
        case 0:
            return "\(capacity) — add from Library"
        case 1 ... 4:
            return "\(capacity) — pick what matters this week"
        default:
            return capacity
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialScreenTitle(title: "Focus", bottomSpacing: 8)
            Text(subline)
                .appTypography(.zoneSubtitle)
                .foregroundStyle(AppPalette.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, AppSpacing.editorialTitleBottom)
        }
    }
}

#Preview {
    FocusStackHeader(activeCount: 0)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .background(AppPalette.background)
}
