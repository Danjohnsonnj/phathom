import SwiftUI

/// Pinned Library search bar shell — accent field + Cancel (§3.2 Search B). Overlay placement in Phase 2.
struct PinnedLibrarySearchBar: View {
    @Binding var text: String
    var onCancel: () -> Void
    var isFieldFocused: FocusState<Bool>.Binding

    private static let fieldHeight: CGFloat = 40

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.accent)
                    .padding(.leading, 12)

                TextField("Search title, tags, source text", text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(isFieldFocused)
                    .padding(.leading, 8)
                    .padding(.trailing, 14)
            }
            .frame(height: Self.fieldHeight)
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppPalette.accent.opacity(0.55), lineWidth: 1.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Search title, tags, source text")

            Button("Cancel", action: onCancel)
                .font(.system(size: 17))
                .foregroundStyle(AppPalette.accent)
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .accessibilityHint("Exit search")
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, 4)
        .background(AppPalette.background.opacity(0.94))
        .overlay(alignment: .bottom) {
            // Search mock uses 0.5px rule — not full 1px gallery hairline.
            Rectangle()
                .fill(AppPalette.hairline)
                .frame(height: 0.5)
        }
    }
}

#Preview {
    PinnedLibrarySearchBarPreview()
}

private struct PinnedLibrarySearchBarPreview: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        PinnedLibrarySearchBar(
            text: $text,
            onCancel: { text = "" },
            isFieldFocused: $isFocused
        )
        .background(AppPalette.background)
        .onAppear { isFocused = true }
    }
}
