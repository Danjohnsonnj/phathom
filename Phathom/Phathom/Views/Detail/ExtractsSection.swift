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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppPalette.textPrimary)
                    Text("·")
                        .foregroundStyle(AppPalette.textSecondary)
                    Text(extract.value)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
