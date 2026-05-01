import SwiftData
import SwiftUI

struct TagChipsView: View {
    let tags: [Tag]

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.name) { tag in
                Text(tag.name.localizedCapitalized)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
    }
}
