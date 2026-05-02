import PhathomCore
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
                                ? AppPalette.accent
                                : AppPalette.surface
                        )
                        .foregroundStyle(
                            selected == option.kind
                                ? AppPalette.floralWhite
                                : AppPalette.dustGrey
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
        .background(AppPalette.background)
}
