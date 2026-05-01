import SwiftUI

struct ExtractsSection: View {
    let extracts: [Extract]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(extracts) { extract in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                    Text(extract.label)
                        .font(.subheadline.weight(.medium))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(extract.value)
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
