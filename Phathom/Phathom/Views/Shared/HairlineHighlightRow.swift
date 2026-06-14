import SwiftUI

/// Hairline highlight row — 4px paprika bar, italic quote, uppercase **Note** when present (Detail + Notebook).
struct HairlineHighlightRow: View {
    let quotedText: String
    let userNote: String?
    var quotedLineLimit: Int?
    var noteLineLimit: Int?
    var showsBottomHairline: Bool = true
    /// Detail rows use 16pt; Notebook feed uses 0 and `AppSpacing.highlightStackGap` between rows.
    var verticalPadding: CGFloat = 16
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AppPalette.accent)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(quotedText)
                        .font(.system(size: 15))
                        .italic()
                        .foregroundStyle(AppPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(quotedLineLimit)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let note = trimmedNote {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Note")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(0.44)
                                .textCase(.uppercase)
                                .foregroundStyle(AppPalette.textSecondary.opacity(0.55))

                            Text(note)
                                .font(.system(size: 15))
                                .foregroundStyle(AppPalette.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(noteLineLimit)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.leading, 10)
            }
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if showsBottomHairline {
                    Rectangle()
                        .fill(AppPalette.hairline)
                        .frame(height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trimmedNote: String? {
        guard let note = userNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }
        return note
    }
}

#Preview("Detail — unlimited") {
    HairlineHighlightRow(
        quotedText: "Token-to-learning is closer to the thing that matters.",
        userNote: "Interesting framing for metrics.",
        onTap: {}
    )
    .padding(.horizontal, AppSpacing.screenHorizontal)
    .background(AppPalette.background)
}

#Preview("Notebook — line limits") {
    HairlineHighlightRow(
        quotedText: "Long quoted passage that should clamp to three lines in the notebook feed preview.",
        userNote: "Short note clamped to two lines in notebook.",
        quotedLineLimit: 3,
        noteLineLimit: 2,
        showsBottomHairline: false,
        onTap: {}
    )
    .padding(.horizontal, AppSpacing.screenHorizontal)
    .background(AppPalette.background)
}
