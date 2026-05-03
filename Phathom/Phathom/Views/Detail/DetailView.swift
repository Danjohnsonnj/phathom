import PhathomCore
import SwiftData
import SwiftUI
import UIKit
import MarkdownUI

struct DetailView: View {
    @Bindable var item: ContentItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sourceExpanded = false
    @State private var titleDraft: String = ""
    @FocusState private var titleFocused: Bool

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

                detailStatusChip

                VStack(alignment: .leading, spacing: 8) {
                    if let host = item.displayHost, item.kind == .web {
                        Text(host)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppPalette.accent)
                    }

                    TextField(item.displayTitle, text: $titleDraft, axis: .vertical)
                        .font(.title.bold())
                        .foregroundStyle(AppPalette.textPrimary)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .focused($titleFocused)
                        .onSubmit { commitTitleDraft() }
                        .onChange(of: titleFocused) { _, isFocused in
                            if !isFocused { commitTitleDraft() }
                        }

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

                failedSection

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
        .onAppear { syncTitleDraftFromItem() }
        .onChange(of: item.title) { _, _ in
            if !titleFocused { syncTitleDraftFromItem() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = shareURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(item: item.displayTitle) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func syncTitleDraftFromItem() {
        titleDraft = item.title ?? ""
    }

    /// Trim, write back to `item.title`, set `titleUserSet` accordingly, persist, and refresh Spotlight.
    /// Clearing the field resets `titleUserSet` so the next scrape can repopulate the title automatically.
    private func commitTitleDraft() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle: String? = trimmed.isEmpty ? nil : String(trimmed.prefix(200))
        let priorTitle = item.title
        let priorFlag = item.titleUserSet
        item.title = newTitle
        item.titleUserSet = (newTitle != nil)
        if newTitle != priorTitle || item.titleUserSet != priorFlag {
            try? modelContext.save()
            item.indexInSpotlight()
        }
        titleDraft = newTitle ?? ""
    }

    private var summarySnippet: String? {
        if item.kind == .note { return nil }
        if let md = item.mediaDescription, !md.isEmpty {
            let clean = SummaryLineSanitization.sanitizedBullet(md)
            if !clean.isEmpty { return clean }
        }
        return item.displaySummaryBullets.first.map { "Summary, \($0)" }
    }

    @ViewBuilder
    private var detailStatusChip: some View {
        ProcessingStatusBadge(status: item.status, onTap: detailChipTapAction)
    }

    private var detailChipTapAction: (() -> Void)? {
        guard item.status == .pending, item.kind == .web else { return nil }
        return {
            BackgroundPipeline.scheduleForegroundDrain()
            BackgroundPipeline.scheduleIngest()
        }
    }

    @ViewBuilder
    private var failedSection: some View {
        if item.status == .failed {
            VStack(alignment: .leading, spacing: 12) {
                Text("Processing failed")
                    .font(.headline.bold())
                    .foregroundStyle(AppPalette.textPrimary)

                Text(failedReasonDisplay)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    _ = ProcessingRecovery.retryFailedItemIfNeeded(item, modelContext: modelContext)
                } label: {
                    Text("Retry")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppPalette.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppPalette.surfaceNested)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!ProcessingRecovery.canRetryFailed(item))

                if item.kind == .note, !noteHasRetryableText {
                    Text("This note has no text to analyze, so it cannot be retried.")
                        .font(.caption)
                        .foregroundStyle(AppPalette.textTertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var failedReasonDisplay: String {
        let t = (item.failureReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Something went wrong." : t
    }

    private var noteHasRetryableText: Bool {
        guard let raw = item.rawText else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var noteRenderedSection: some View {
        if item.kind == .note, let raw = item.rawText, !raw.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Note")
                    .font(.headline.bold())
                    .foregroundStyle(AppPalette.textPrimary)
                Markdown(raw)
                    .markdownTheme(.phathomNote)
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
                    ForEach(Array(item.displaySummaryBullets.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if item.status == .failed {
                Text("Not available until processing succeeds.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
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
            if item.isArchived {
                restoreToLibraryButton
            } else {
                archiveButton
            }
        }
    }

    /// Clears `isArchived` / `archivedAt` and returns the item to the main Library query (`!isArchived`).
    private var restoreToLibraryButton: some View {
        Button {
            ArchiveRetention.restore(item)
            try? modelContext.save()
            NotificationCenter.default.post(name: .phathomArchivedItemsDidChange, object: nil)
            dismiss()
        } label: {
            Text("Restore to Library")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.floralWhite)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var archiveButton: some View {
        Button {
            ArchiveRetention.archive(item)
            try? modelContext.save()
            dismiss()
            let archivedID = item.id
            Task { @MainActor in
                await Task.yield()
                NotificationCenter.default.post(
                    name: .phathomDidArchiveItem,
                    object: nil,
                    userInfo: ["itemID": archivedID, "switchToLibrary": true]
                )
            }
        } label: {
            Text("Archive")
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

    private var sourceMarkdownForDisplay: String? {
        guard item.kind == .web, let md = item.sourceMarkdown else { return nil }
        let t = md.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : md
    }

    /// MarkdownUI paragraph styles use `fixedSize(vertical: true)`, so `lineLimit` on `Markdown` does not
    /// truncate. Match ~8 lines of body text using Dynamic Type–aware line height, then clip.
    private var collapsedSourceMarkdownMaxHeight: CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        return ceil(font.lineHeight * 8)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Source Content")
                .font(.headline.bold())
                .foregroundStyle(AppPalette.textPrimary)

            if let md = sourceMarkdownForDisplay {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sourceExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Group {
                            if sourceExpanded {
                                Markdown(md)
                                    .markdownTheme(.phathomNote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            } else {
                                Markdown(md)
                                    .markdownTheme(.phathomNote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(maxHeight: collapsedSourceMarkdownMaxHeight, alignment: .top)
                                    .clipped()
                            }
                        }
                        .accessibilityHidden(true)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.textTertiary)
                            .rotationEffect(.degrees(sourceExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sourceExpanded ? "Source content, expanded" : "Source content, collapsed preview")
                .accessibilityHint("Double tap to expand or collapse the full source text.")
            } else if let raw = item.rawText, !raw.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sourceExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Group {
                            if sourceExpanded {
                                Text(raw)
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            } else {
                                Text(raw)
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .accessibilityHidden(true)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.textTertiary)
                            .rotationEffect(.degrees(sourceExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sourceExpanded ? "Source content, expanded" : "Source content, collapsed preview")
                .accessibilityHint("Double tap to expand or collapse the full source text.")
            } else {
                Text("No source text")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
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
