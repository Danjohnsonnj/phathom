import PhathomCore
import SwiftUI

struct ExtractsSection: View {
    let extracts: [Extract]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(extracts) { extract in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                        .foregroundStyle(AppPalette.textSecondary)
                    Text(extract.label)
                        .appTypography(.subsectionHeader)
                        .foregroundStyle(AppPalette.textPrimary)
                    Text("·")
                        .foregroundStyle(AppPalette.textSecondary)
                    Text(extract.value)
                        .appTypography(.zoneSubtitle)
                        .foregroundStyle(AppPalette.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
