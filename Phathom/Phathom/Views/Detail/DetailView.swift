import SwiftData
import SwiftUI
import MarkdownUI

struct DetailView: View {
    @Bindable var item: ContentItem

    @State private var sourceExpanded = false
    @State private var showStubAlert = false
    @State private var stubMessage = ""

    private static let timestampFormat = Date.FormatStyle()
        .month(.abbreviated)
        .day()
        .year()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()
        .locale(.init(identifier: "en_US_POSIX"))

    private var shareURL: URL? {
        item.originalURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroSection(item: item)

                VStack(alignment: .leading, spacing: 8) {
                    if let host = item.displayHost, item.kind == .web {
                        Text(host)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppPalette.accent)
                    }

                    Text(item.title ?? "Untitled")
                        .font(.title.bold())
                        .foregroundStyle(AppPalette.textPrimary)

                    if let snippet = summarySnippet {
                        Text(snippet)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)
                    }

                    Text(item.createdAt.formatted(Self.timestampFormat))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                noteRenderedSection

                summarySection

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.headline.bold())
                        .foregroundStyle(AppPalette.textPrimary)
                    if item.tags.isEmpty {
                        Text("No tags")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)
                    } else {
                        TagChipsView(tags: item.tags)
                    }
                }

                if !item.decodedExtracts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Extracted Key Figures")
                            .font(.headline.bold())
                            .foregroundStyle(AppPalette.textPrimary)
                        ExtractsSection(extracts: item.decodedExtracts)
                    }
                }

                actionButtons

                sourceSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(AppPalette.background)
        .navigationTitle("Phathom")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = shareURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(item: item.title ?? "") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .alert("Coming soon", isPresented: $showStubAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(stubMessage) is not available in this build.")
        }
    }

    private var summarySnippet: String? {
        if item.kind == .note { return nil }
        if let md = item.mediaDescription, !md.isEmpty { return md }
        return item.decodedSummaryBullets.first.map { "Summary, \($0)" }
    }

    @ViewBuilder
    private var noteRenderedSection: some View {
        if item.kind == .note, let raw = item.rawText, !raw.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Note")
                    .font(.headline.bold())
                    .foregroundStyle(AppPalette.textPrimary)
                Markdown(raw)
                    .markdownTheme(.gitHub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Summary")
                .font(.headline.bold())
                .foregroundStyle(AppPalette.textPrimary)

            if item.status == .completed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.decodedSummaryBullets.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppPalette.surfaceNested)
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(16)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                stubButton("Read Full Text (AI Parsed)")
                stubButton("Translate")
            }
            stubButton("Archive")
        }
    }

    private func stubButton(_ title: String) -> some View {
        Button {
            stubMessage = title
            showStubAlert = true
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppPalette.surfaceNested)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Source Content")
                .font(.headline.bold())
                .foregroundStyle(AppPalette.textPrimary)

            if let raw = item.rawText, !raw.isEmpty {
                DisclosureGroup(isExpanded: $sourceExpanded) {
                    Text(raw)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } label: {
                    Text(raw.prefixLinePreview(lineCount: 4))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                        .lineLimit(4)
                }
            } else {
                Text("No source text")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
    }
}

private extension String {
    func prefixLinePreview(lineCount: Int) -> String {
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
        let head = lines.prefix(lineCount).joined(separator: "\n")
        return String(head)
    }
}

private struct DetailPreviewHost: View {
    @Query(filter: #Predicate<ContentItem> { $0.title == "Future City Concepts" })
    private var items: [ContentItem]

    var body: some View {
        NavigationStack {
            if let item = items.first {
                DetailView(item: item)
            } else {
                Text("No preview item")
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
    }
}

#Preview("Detail") {
    DetailPreviewHost()
        .modelContainer(PreviewModel.makeContainer())
}
