import PhathomCore
import SwiftData
import SwiftUI
import UIKit
import MarkdownUI

struct DetailView: View {
    @Bindable var item: ContentItem
    /// Optional handler invoked when the user picks a related item from the tag-tap sheet.
    /// `LibraryTab` supplies a handler that replaces its `NavigationPath` so the user lands on the
    /// chosen item's detail. Call sites without their own NavigationStack (preview, RecentlyDeletedView)
    /// can omit this; tapping a related item will simply dismiss the sheet.
    var onRelatedItemSelected: ((UUID) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sourceExpanded = false
    @State private var titleDraft: String = ""
    @State private var relatedSheetTag: Tag?
    @State private var isTagEditMode = false
    @State private var isTagEditorPresented = false
    @State private var tagEditorMode: TagEditorMode = .add
    @State private var tagEditorDraft = ""
    @State private var tagEditorErrorMessage: String?
    @State private var delaySummarizeDisable = false
    @State private var noteEditHighlight: Highlight?
    @State private var sourceWebSelectionActive = false
    @State private var sourceWebHighlightApplyToken = 0
    @FocusState private var titleFocused: Bool

    private static let timestampFormat = Date.FormatStyle()
        .month(.abbreviated)
        .day()
        .year()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()
        .locale(.init(identifier: "en_US_POSIX"))
    private static let summarizeDisableSettleDelayNs: UInt64 = 750_000_000

    private var shareURL: URL? {
        item.originalURL
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
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

                    if let snippet = summarySnippetMarkdown {
                        Markdown(snippet)
                            .markdownTheme(.phathomNote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let snippet = summarySnippetPlain {
                        Text(snippet)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)
                    }

                    Text(item.createdAt.formatted(Self.timestampFormat))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if titleFocused { titleFocused = false }
                }

                noteRenderedSection

                failedSection

                readingStatusSection

                summarySection

                tagsSection

                if !item.decodedExtracts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Extracted Key Figures")
                            .font(.headline.bold())
                            .foregroundStyle(AppPalette.textPrimary)
                        ExtractsSection(extracts: item.decodedExtracts)
                    }
                }

                HighlightsNotesSection(
                    highlights: item.highlightsSortedByOffset,
                    showsEmptyPlaceholder: item.kind == .web
                ) { tapped in
                    noteEditHighlight = tapped
                }

                actionButtons

                sourceSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .id(item.id)
        .background(AppPalette.background)
        .navigationTitle("Phathom")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailToolbar }
        .onAppear {
            syncTitleDraftFromItem()
            ensureSourceContentHTMLIfNeeded()
        }
        .onChange(of: item.title) { _, _ in
            if !titleFocused { syncTitleDraftFromItem() }
        }
        .onChange(of: item.sourceMarkdown) { _, _ in
            ensureSourceContentHTMLIfNeeded()
        }
        .sheet(item: $relatedSheetTag) { tag in
            RelatedItemsSheet(sourceItem: item, tappedTag: tag) { selected in
                let id = selected.id
                relatedSheetTag = nil
                onRelatedItemSelected?(id)
            }
        }
        .sheet(isPresented: $isTagEditorPresented) {
            TagEditorSheetView(
                title: tagEditorMode.title,
                text: $tagEditorDraft,
                showsDelete: tagEditorMode.isEditingExistingTag,
                saveLabel: "Save",
                onSave: { saveTagChanges(for: tagEditorMode) },
                onDelete: tagEditorMode.isEditingExistingTag ? { deleteTag(for: tagEditorMode) } : nil,
                onCancel: dismissTagEditor,
                validationMessage: tagValidationMessage,
                errorMessage: tagEditorErrorMessage
            )
        }
        .sheet(item: $noteEditHighlight) { highlight in
            HighlightNoteEditSheet(
                highlight: highlight,
                modelContext: modelContext,
                onDismiss: { noteEditHighlight = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
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

    private var tagValidationMessage: String? {
        let trimmed = tagEditorDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if TagNameNormalizer.normalize(tagEditorDraft) == nil {
            return "Use 2-40 chars: letters, numbers, or hyphens."
        }
        return nil
    }

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.headline.bold())
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer()
                Button(isTagEditMode ? "Done" : "Edit") {
                    isTagEditMode.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(AppPalette.accent)
                .accessibilityLabel(isTagEditMode ? "Done editing tags" : "Edit tags")
            }
            if item.tags.isEmpty {
                Text("No tags")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
            }
            if isTagEditMode {
                TagChipsView(
                    tags: item.tags,
                    onTap: { tag in presentEditSheet(for: tag) },
                    accessibilityHintProvider: { _ in "Edit this tag" },
                    addActionTitle: "Add new",
                    onAddAction: presentAddSheet
                )
            } else {
                TagChipsView(
                    tags: item.tags,
                    onTap: { tag in relatedSheetTag = tag },
                    accessibilityHintProvider: { _ in "Show related items" }
                )
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
            DetailModelSave.save(modelContext, operation: "commitTitleDraft")
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            item.indexInSpotlight()
        }
        titleDraft = newTitle ?? ""
    }

    private func presentEditSheet(for tag: Tag) {
        tagEditorDraft = tag.name
        tagEditorErrorMessage = nil
        tagEditorMode = .edit(originalTagName: tag.name)
        isTagEditorPresented = true
    }

    private func presentAddSheet() {
        tagEditorDraft = ""
        tagEditorErrorMessage = nil
        tagEditorMode = .add
        isTagEditorPresented = true
    }

    private func dismissTagEditor() {
        isTagEditorPresented = false
        tagEditorDraft = ""
        tagEditorErrorMessage = nil
    }

    private func saveTagChanges(for sheet: TagEditorMode) {
        guard let normalized = TagNameNormalizer.normalize(tagEditorDraft) else {
            tagEditorErrorMessage = "Tag format invalid."
            return
        }
        switch sheet {
        case .add:
            attachTagIfNeeded(named: normalized)
        case let .edit(originalTagName):
            if normalized == originalTagName {
                dismissTagEditor()
                return
            }
            item.tags.removeAll(where: { $0.name == originalTagName })
            attachTagIfNeeded(named: normalized)
        }
        do {
            try modelContext.save()
        } catch {
            tagEditorErrorMessage = "Failed to save tag changes."
            return
        }
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        item.indexInSpotlight()
        dismissTagEditor()
    }

    private func deleteTag(for sheet: TagEditorMode) {
        guard case let .edit(originalTagName) = sheet else { return }
        item.tags.removeAll(where: { $0.name == originalTagName })
        do {
            try modelContext.save()
        } catch {
            tagEditorErrorMessage = "Failed to delete tag."
            return
        }
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        item.indexInSpotlight()
        dismissTagEditor()
    }

    private func attachTagIfNeeded(named normalizedName: String) {
        guard !item.tags.contains(where: { $0.name == normalizedName }) else { return }
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { $0.name == normalizedName }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        let tag = existing ?? {
            let created = Tag(name: normalizedName)
            modelContext.insert(created)
            return created
        }()
        item.tags.append(tag)
    }

    private var summarySnippetMarkdown: String? {
        if let source = item.sourceMarkdown,
           let preview = SummaryLineSanitization.sourceMarkdownPreview(source, maxWords: 50)
        {
            return preview
        }
        return nil
    }

    private var summarySnippetPlain: String? {
        if item.kind == .media, let md = item.mediaDescription, !md.isEmpty {
            let clean = SummaryLineSanitization.sanitizedBullet(md)
            if !clean.isEmpty { return clean }
        }
        if let raw = item.rawText,
           let preview = SummaryLineSanitization.sourcePreview(raw, maxWords: 50)
        {
            return preview
        }
        return nil
    }

    @ViewBuilder
    private var detailStatusChip: some View {
        ProcessingStatusBadge(status: item.status, onTap: detailChipTapAction)
    }

    private var readingStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Reading status", selection: readStatusBinding) {
                ForEach(ReadStatus.allCases, id: \.self) { status in
                    Text(ReadStatusPresentation.label(for: status)).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppPalette.accent)
        }
        .accessibilityElement(children: .contain)
    }

    private var readStatusBinding: Binding<ReadStatus> {
        Binding(
            get: { item.readState },
            set: { item.applyReadStatus($0, modelContext: modelContext) }
        )
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
                if summarizeAgainButtonVisible {
                    summarizeAgainButton
                }
                if regenerateTagsButtonVisible {
                    regenerateTagsButton
                }
                archiveButton
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var summarizeAgainButtonVisible: Bool {
        guard !item.isArchived else { return false }
        switch item.kind {
        case .media:
            return false
        case .web, .note:
            guard let raw = item.rawText else { return false }
            return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var summarizeAgainButtonDisabled: Bool {
        let disableNow = !ProcessingRecovery.canSummarizeAgain(item)
        if delaySummarizeDisable, disableNow {
            return false
        }
        return disableNow
    }

    private var regenerateTagsButtonVisible: Bool {
        summarizeAgainButtonVisible
    }

    private var regenerateTagsButtonDisabled: Bool {
        !ProcessingRecovery.canRegenerateTags(item)
    }

    private var summarizeAgainButton: some View {
        Button {
            guard ProcessingRecovery.summarizeAgain(item, modelContext: modelContext) else { return }
            delaySummarizeDisable = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.summarizeDisableSettleDelayNs)
                delaySummarizeDisable = false
            }
        } label: {
            Text("Summarize again")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(summarizeAgainButtonDisabled ? AppPalette.textSecondary : AppPalette.accent)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(summarizeAgainButtonDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(summarizeAgainButtonDisabled)
        .accessibilityHint(
            "Clears the current summary, tags, and extracts, then runs the full pipeline again: summary, tagging, and key extracts."
        )
    }

    private var regenerateTagsButton: some View {
        Button {
            _ = ProcessingRecovery.regenerateTags(item, modelContext: modelContext)
        } label: {
            Text("Regenerate tags")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(regenerateTagsButtonDisabled ? AppPalette.textSecondary : AppPalette.accent)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(regenerateTagsButtonDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(regenerateTagsButtonDisabled)
        .accessibilityHint(
            "Replaces tags from summary + key extracts. For Instagram and TikTok web captures, caption hashtags are still merged after tagging."
        )
    }

    /// Clears `isArchived` / `archivedAt` and returns the item to the main Library query (`!isArchived`).
    private var restoreToLibraryButton: some View {
        Button {
            ArchiveRetention.restore(item)
            DetailModelSave.save(modelContext, operation: "restoreToLibrary")
            LibraryContentChangeNotifier.postLibraryContentDidChange()
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
            DetailModelSave.save(modelContext, operation: "archiveItem")
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            dismiss()
            let archivedID = item.id
            Task { @MainActor in
                await Task.yield()
                NotificationCenter.default.post(
                    name: .phathomDidArchiveItem,
                    object: nil,
                    userInfo: PhathomArchiveNotification.userInfo(itemIDs: [archivedID])
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
        guard item.kind == .web, let md = item.sourceMarkdown, !md.isEmpty else { return nil }
        return md
    }

    private var collapsedSourceMarkdownMaxHeight: CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        return ceil(font.lineHeight * 8)
    }

    private func createHighlightFromWebView(offset: Int, length: Int, quotedText: String) {
        guard item.kind == .web, let md = item.sourceMarkdown, !md.isEmpty else { return }
        let maxLen = md.utf16.count
        guard offset >= 0, length > 0, offset + length <= maxLen else { return }
        let h = Highlight(sourceMarkdownOffset: offset, sourceMarkdownLength: length, quotedText: quotedText)
        modelContext.insert(h)
        item.highlights.append(h)
        guard DetailModelSave.save(modelContext, operation: "createHighlight") == nil else { return }
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        noteEditHighlight = h
    }

    /// Backfills or refreshes `sourceContentHTML` when markdown exists but HTML is missing or indexer version is stale.
    private func ensureSourceContentHTMLIfNeeded() {
        guard item.kind == .web else { return }
        guard let md = item.sourceMarkdown else { return }
        let htmlMissing = (item.sourceContentHTML ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let versionStale = item.sourceContentIndexVersion < SourceContentIndexer.currentVersion
        guard htmlMissing || versionStale else { return }
        let normalized = md
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        item.sourceMarkdown = normalized
        guard let indexed = SourceContentIndexer.index(markdown: normalized) else { return }
        item.sourceContentHTML = indexed.html
        item.sourceContentIndexVersion = indexed.version
        guard DetailModelSave.save(modelContext, operation: "ensureSourceContentHTML") == nil else { return }
        LibraryContentChangeNotifier.postLibraryContentDidChange()
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sourceExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Source Content")
                        .font(.headline.bold())
                        .foregroundStyle(AppPalette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.textTertiary)
                        .rotationEffect(.degrees(sourceExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sourceExpanded ? "Source content, expanded" : "Source content, collapsed preview")
            .accessibilityHint("Double tap to expand or collapse the full source text.")

            if let html = item.sourceContentHTML, !html.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HighlightableMarkdownWebView(
                        selectionActive: $sourceWebSelectionActive,
                        highlightApplyToken: $sourceWebHighlightApplyToken,
                        sourceHTML: html,
                        highlights: item.highlightsSortedByOffset,
                        collapsed: !sourceExpanded,
                        onCreateHighlight: { offset, length, quotedText in
                            createHighlightFromWebView(offset: offset, length: length, quotedText: quotedText)
                        },
                        onTapHighlight: { noteEditHighlight = $0 }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let md = sourceMarkdownForDisplay {
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

private enum DetailModelSave {
    @discardableResult
    static func save(_ context: ModelContext, operation: String) -> String? {
        do {
            try context.save()
            return nil
        } catch {
            #if DEBUG
            assertionFailure("[DetailModelSave] \(operation): \(error)")
            #endif
            print("[DetailModelSave] \(operation) failed: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }
}

private struct HighlightNoteEditSheet: View {
    @Bindable var highlight: Highlight
    var modelContext: ModelContext
    var onDismiss: () -> Void

    @State private var noteDraft: String = ""
    @State private var persistenceError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(highlight.quotedText)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.surface)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(AppPalette.accent)
                                .frame(width: 4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    TextEditor(text: $noteDraft)
                        .frame(minHeight: 140)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(AppPalette.surfaceNested)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(AppPalette.textPrimary)

                    if let persistenceError {
                        Text(persistenceError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        persistenceError = nil
                        let t = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        highlight.userNote = t.isEmpty ? nil : String(t.prefix(10_000))
                        if let err = DetailModelSave.save(modelContext, operation: "saveHighlightNote") {
                            persistenceError = err
                        } else {
                            LibraryContentChangeNotifier.postLibraryContentDidChange()
                            onDismiss()
                        }
                    } label: {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.floralWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        persistenceError = nil
                        highlight.userNote = nil
                        if let err = DetailModelSave.save(modelContext, operation: "deleteHighlightNote") {
                            persistenceError = err
                        } else {
                            LibraryContentChangeNotifier.postLibraryContentDidChange()
                            onDismiss()
                        }
                    } label: {
                        Text("Delete note")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.surfaceNested)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        persistenceError = nil
                        modelContext.delete(highlight)
                        if let err = DetailModelSave.save(modelContext, operation: "removeHighlight") {
                            persistenceError = err
                        } else {
                            LibraryContentChangeNotifier.postLibraryContentDidChange()
                            onDismiss()
                        }
                    } label: {
                        Text("Remove highlight")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
            }
            .background(AppPalette.background)
            .navigationTitle("Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
            .onAppear { noteDraft = highlight.userNote ?? "" }
        }
    }
}

private enum TagEditorMode {
    case add
    case edit(originalTagName: String)

    var title: String {
        switch self {
        case .add:
            return "Add Tag"
        case .edit:
            return "Edit Tag"
        }
    }

    var isEditingExistingTag: Bool {
        if case .edit = self { return true }
        return false
    }
}

private struct TagEditorSheetView: View {
    let title: String
    @Binding var text: String
    let showsDelete: Bool
    let saveLabel: String
    let onSave: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    let validationMessage: String?
    let errorMessage: String?

    private var normalizedDraft: String? {
        TagNameNormalizer.normalize(text)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Tag", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)

                    if showsDelete, let onDelete {
                        Button("Delete", role: .destructive, action: onDelete)
                            .buttonStyle(.bordered)
                    }

                    Button(saveLabel, action: onSave)
                        .buttonStyle(.borderedProminent)
                        .disabled(normalizedDraft == nil)
                }
            }
            .padding(16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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
