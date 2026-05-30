import SwiftUI

struct HighlightCardView: View {
    let quotedText: String
    let userNote: String?
    var quotedLineLimit: Int? = nil
    var noteLineLimit: Int? = nil
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(quotedText)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(quotedLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let note = trimmedNote {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(noteLineLimit)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surface)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(AppPalette.accent)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
