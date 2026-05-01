import SwiftUI

struct FilterPills: View {
    @Binding var selected: ContentKind?

    private let options: [(label: String, kind: ContentKind?)] = [
        ("All", nil),
        ("Web", .web),
        ("Media", .media),
        ("Notes", .note),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.label) { option in
                Button {
                    selected = option.kind
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selected == option.kind
                                ? Color.accentColor
                                : Color(.tertiarySystemFill)
                        )
                        .foregroundStyle(
                            selected == option.kind
                                ? Color.white
                                : Color.primary
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    struct Binder: View {
        @State private var selected: ContentKind?
        var body: some View {
            FilterPills(selected: $selected)
                .padding()
        }
    }
    return Binder()
}
