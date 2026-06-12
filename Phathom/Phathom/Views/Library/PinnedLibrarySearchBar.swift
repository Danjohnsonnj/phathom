import SwiftUI

/// Pinned Library search bar shell — accent field + Close (§3.2 Search B). Overlay placement in Phase 2.
struct PinnedLibrarySearchBar: View {
    @Binding var text: String
    var onClose: () -> Void
    var isFieldFocused: FocusState<Bool>.Binding

    private static let fieldHeight: CGFloat = 40

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.accent)
                    .padding(.leading, 12)

                TextField("Search title, tags, source, highlights", text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(isFieldFocused)
                    .padding(.leading, 8)
                    .padding(.trailing, text.isEmpty ? 14 : 4)

                if !text.isEmpty {
                    Button {
                        text = ""
                        isFieldFocused.wrappedValue = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(AppPalette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                    .accessibilityLabel("Clear search text")
                }
            }
            .frame(height: Self.fieldHeight)
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppPalette.accent.opacity(0.55), lineWidth: 1.5)
            }

            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 17))
                    .phathomToolbarTextLabel()
            }
            .foregroundStyle(AppPalette.accent)
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .accessibilityLabel("Close")
            .accessibilityHint("Close search field and keep current search")
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(AppPalette.background.opacity(0.94))
        }
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
    @State private var text = "sample"
    @FocusState private var isFocused: Bool

    var body: some View {
        PinnedLibrarySearchBar(
            text: $text,
            onClose: { isFocused = false },
            isFieldFocused: $isFocused
        )
        .background(AppPalette.background)
        .onAppear { isFocused = true }
    }
}
