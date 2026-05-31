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
    @State private var pendingFileCategorySheet = false
    @State private var detailCategoryPickHandled = false
    @State private var isCategoryPickerPresented = false
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
            VStack(alignment: .leading, spacing: 0) {
                HeroSection(item: item)

                VStack(alignment: .leading, spacing: 0) {
                    headerBlock

                    sourceContentSection
                        .detailSection(topHairline: true, vertical: .spaced)

                    readingStatusSection
                        .detailSection(topHairline: true, vertical: .compact)

                    categorySection
                        .detailSection(topHairline: true, vertical: .compact)

                    if !item.highlightsSortedByOffset.isEmpty || item.kind == .web {
                        HighlightsNotesSection(
                            highlights: item.highlightsSortedByOffset,
                            showsEmptyPlaceholder: item.kind == .web
                        ) { tapped in
                            noteEditHighlight = tapped
                        }
                        .detailSection(topHairline: true, vertical: .spaced)
                    }

                    aiAnalysisZone
                        .detailSection(topHairline: true, vertical: .spaced)

                    actionButtons
                        .detailSection(topHairline: true, vertical: .actions)
                }
            }
            .padding(.bottom, 32)
        }
        .id(item.id)
        .background(AppPalette.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            DetailPushNavBar {
                DetailShareBarButton(shareURL: shareURL, fallbackTitle: item.displayTitle)
            }
        }
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
        .sheet(isPresented: $pendingFileCategorySheet, onDismiss: detailFileCategoryOnDismiss) {
            CategoryPicker { picked in
                detailCategoryPickHandled = true
                item.applyFiled(category: picked, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $isCategoryPickerPresented) {
            CategoryPicker(
                toolbarCancelPassesSelection: false,
                navigationTitle: "Category"
            ) { picked in
                item.applyCategory(picked, modelContext: modelContext)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailStatusChip

            failedSection

            headerSection
        }
        .detailSection(topHairline: false, vertical: .spaced)
    }

    private var headerSection: some View {
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

            Text(item.createdAt.formatted(Self.timestampFormat))
                .font(.subheadline)
                .foregroundStyle(AppPalette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if titleFocused { titleFocused = false }
        }
    }

    @ViewBuilder
    private var extractsSection: some View {
        if item.kind != .media, !item.decodedExtracts.isEmpty {
            aiSubsection {
                DetailAISubsectionHeader(title: "Key Figures")
                ExtractsSection(extracts: item.decodedExtracts)
            }
        }
    }

    private var aiAnalysisZone: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZoneSectionHeader(title: "AI analysis")
                .padding(.bottom, 22)

            tagsSection

            if item.kind != .media {
                aiSubsection {
                    summarySection
                }
            }

            extractsSection
        }
    }

    /// Subsection after Tags / Summary — mock: 22pt above hairline, hairline, 22pt to header, 12pt header→body.
    @ViewBuilder
    private func aiSubsection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppPalette.hairline)
                .frame(maxWidth: .infinity)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.aiSubsectionHairlineGap)
        }
        .padding(.top, AppSpacing.aiSubsectionHairlineGap)
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
            DetailAITagsSectionHeader(title: "Tags", isEditMode: isTagEditMode) {
                isTagEditMode.toggle()
            }
            if item.tags.isEmpty {
                Text("No tags")
                    .font(.system(size: 15))
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

    @ViewBuilder
    private var detailStatusChip: some View {
        ProcessingStatusBadge(
            status: item.status,
            contentKind: item.kind,
            processingDetail: item.processingDetail,
            onTap: detailChipTapAction
        )
    }

    private var readingStatusSection: some View {
        Picker("Reading status", selection: readStatusBinding) {
            ForEach(ReadStatus.allCases, id: \.self) { status in
                Text(ReadStatusPresentation.label(for: status)).tag(status)
            }
        }
        .pickerStyle(.segmented)
        .tint(AppPalette.accent)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var categorySectionDisplayName: String {
        if let cat = item.category {
            return CategoryDisplayFormatter.displayName(cat.name)
        }
        return "Uncategorized"
    }

    private var categorySection: some View {
        HStack(spacing: 8) {
            Text("Category")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.34)
                .foregroundStyle(AppPalette.textPrimary)
            Spacer(minLength: 8)
            Text(categorySectionDisplayName)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.textPrimary)
            Button("Edit") {
                isCategoryPickerPresented = true
            }
            .font(.system(size: 15, weight: .semibold))
            .tracking(-0.15)
            .buttonStyle(.plain)
            .foregroundStyle(AppPalette.accent)
            .accessibilityLabel("Edit category")
            .accessibilityHint("Opens a list to choose, create, or clear the category.")
        }
        .frame(minHeight: 48, alignment: .center)
    }

    private var readStatusBinding: Binding<ReadStatus> {
        Binding(
            get: { item.readState },
            set: { newValue in
                if newValue == .filed, item.readState != .filed {
                    pendingFileCategorySheet = true
                    return
                }
                item.applyReadStatus(newValue, modelContext: modelContext)
            }
        )
    }

    private func detailFileCategoryOnDismiss() {
        let handled = detailCategoryPickHandled
        detailCategoryPickHandled = false
        guard !handled else { return }
        item.applyFiled(category: nil, modelContext: modelContext)
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
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.34)
                    .foregroundStyle(AppPalette.textPrimary)

                Text(failedReasonDisplay)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    _ = ProcessingRecovery.retryFailedItemIfNeeded(item, modelContext: modelContext)
                } label: {
                    detailHairlineButtonLabel(
                        "Retry",
                        foreground: AppPalette.textPrimary,
                        disabled: !ProcessingRecovery.canRetryFailed(item)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!ProcessingRecovery.canRetryFailed(item))

                if item.kind == .note, !noteHasRetryableText {
                    Text("This note has no text to analyze, so it cannot be retried.")
                        .font(.caption)
                        .foregroundStyle(AppPalette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailAISubsectionHeader(title: "Summary")

            if item.status == .completed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.displaySummaryBullets.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 15))
                                .foregroundStyle(AppPalette.textSecondary)
                            Text(line)
                                .font(.system(size: 15))
                                .foregroundStyle(AppPalette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            } else if item.status == .failed {
                Text("Not available until processing succeeds.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        guard item.status != .failed else { return false }
        switch item.kind {
        case .media:
            return ModelManager.hasReadableVisionSelection
                && item.thumbnailData.map { !$0.isEmpty } == true
        case .web, .note:
            guard let raw = item.rawText else { return false }
            return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var analyzeAgainButtonTitle: String {
        item.kind == .media ? "Analyze again" : "Summarize again"
    }

    private var analyzeAgainAccessibilityHint: String {
        switch item.kind {
        case .media:
            "Clears the current description and tags, then runs photo analysis again."
        case .web, .note:
            "Clears the current summary, tags, and extracts, then runs the full pipeline again: summary, tagging, and key extracts."
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
        item.kind != .media && summarizeAgainButtonVisible
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
            detailHairlineButtonLabel(
                analyzeAgainButtonTitle,
                foreground: summarizeAgainButtonDisabled ? AppPalette.textSecondary : AppPalette.accent,
                disabled: summarizeAgainButtonDisabled
            )
        }
        .buttonStyle(.plain)
        .disabled(summarizeAgainButtonDisabled)
        .accessibilityHint(analyzeAgainAccessibilityHint)
    }

    private var regenerateTagsButton: some View {
        Button {
            _ = ProcessingRecovery.regenerateTags(item, modelContext: modelContext)
        } label: {
            detailHairlineButtonLabel(
                "Regenerate tags",
                foreground: regenerateTagsButtonDisabled ? AppPalette.textSecondary : AppPalette.accent,
                disabled: regenerateTagsButtonDisabled
            )
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
            detailHairlineButtonLabel("Restore to Library", foreground: Color.green.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private var archiveButton: some View {
        Button {
            ArchiveRetention.archive(item)
            DetailModelSave.save(modelContext, operation: "archiveItem")
            ArchiveRetention.notifyProcessingCancelAfterArchiveCommitted(itemIDs: [item.id])
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
            detailHairlineButtonLabel("Archive", foreground: AppPalette.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private func detailHairlineButtonLabel(
        _ title: String,
        foreground: Color,
        disabled: Bool = false
    ) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .tracking(-0.15)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.hairline, lineWidth: 1)
            }
            .opacity(disabled ? 0.6 : 1.0)
    }

    private var sourceMarkdownForDisplay: String? {
        guard item.kind == .web, let md = item.sourceMarkdown, !md.isEmpty else { return nil }
        return md
    }

    private var collapsedSourceMarkdownMaxHeight: CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        return ceil(font.lineHeight * 8)
    }

    private var mediaSourceContentInFlight: Bool {
        switch item.status {
        case .completed, .failed:
            return false
        case .pending, .scraping, .embedding, .summarizing, .extracting, .tagging:
            return true
        }
    }

    @ViewBuilder
    private var mediaSourceContentBody: some View {
        switch item.status {
        case .failed:
            Text("Not available until processing succeeds.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        default:
            if mediaSourceContentInFlight {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppPalette.surfaceNested)
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                            .redacted(reason: .placeholder)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let desc = (item.mediaDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !desc.isEmpty {
                    Group {
                        if sourceExpanded {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.textSecondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        } else {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("No description generated")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                }
            }
        }
    }

    private func createHighlightFromWebView(quotedText: String, hintOffset: Int?) {
        guard item.kind == .web, let md = item.sourceMarkdown, !md.isEmpty else { return }
        guard let resolved = HighlightMarkdownAnchor.resolveFromSelection(
            markdown: md,
            quotedText: quotedText,
            hintMarkdownOffset: hintOffset
        ) else {
            let preview = quotedText.prefix(40)
            print("[DetailView] highlight anchor unresolved — skip save (quotedText length=\(quotedText.utf16.count) hint=\(hintOffset.map(String.init) ?? "nil") preview=\"\(preview)\")")
            return
        }
        let segmentsJSON = Self.encodeHighlightSegmentsJSON(resolved.segments)
        print("[DetailView] highlight saved (\(resolved.matchQuality.rawValue)) offset=\(resolved.offset) length=\(resolved.length)")
        let h = Highlight(
            sourceMarkdownOffset: resolved.offset,
            sourceMarkdownLength: resolved.length,
            quotedText: quotedText,
            sourceMarkdownSegmentsJSON: segmentsJSON
        )
        modelContext.insert(h)
        item.highlights.append(h)
        guard DetailModelSave.save(modelContext, operation: "createHighlight") == nil else { return }
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        noteEditHighlight = h
    }

    private static func encodeHighlightSegmentsJSON(_ segments: [HighlightMarkdownAnchor.Segment]) -> String? {
        guard !segments.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(segments) else { return nil }
        return String(data: data, encoding: .utf8)
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

    private var sourceContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sourceExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Source Content")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.34)
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

            if item.kind == .note {
                if let raw = item.rawText, !raw.isEmpty {
                    if sourceExpanded {
                        Markdown(raw)
                            .markdownTheme(.phathomNote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Markdown(raw)
                            .markdownTheme(.phathomNote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(maxHeight: collapsedSourceMarkdownMaxHeight, alignment: .top)
                            .clipped()
                    }
                } else {
                    Text("No source text")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                }
            } else if item.kind == .media {
                mediaSourceContentBody
            } else if let html = item.sourceContentHTML, !html.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HighlightableMarkdownWebView(
                        selectionActive: $sourceWebSelectionActive,
                        highlightApplyToken: $sourceWebHighlightApplyToken,
                        sourceHTML: html,
                        highlights: item.highlightsSortedByOffset,
                        collapsed: !sourceExpanded,
                        onCreateHighlight: { quotedText, hintOffset in
                            createHighlightFromWebView(
                                quotedText: quotedText,
                                hintOffset: hintOffset
                            )
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
            } else {
                Text("No source text")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
    }
}

private enum DetailSectionVertical {
    case spaced
    case compact
    case actions

    /// Padding below section hairline before section content (mock `.detail-section--spaced` / `.action-buttons`).
    var topAfterHairline: CGFloat { AppSpacing.detailSectionAfterHairlineGap }

    var bottom: CGFloat {
        switch self {
        case .spaced, .compact: 20
        case .actions: 24
        }
    }
}

private extension View {
    /// Hairline at section top, then content inset below (mock `.detail-section + .detail-section` border-top rhythm).
    func detailSection(topHairline: Bool, vertical: DetailSectionVertical) -> some View {
        Group {
            if topHairline {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(AppPalette.hairline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)

                    self
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, vertical.topAfterHairline)
                }
            } else {
                self
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, vertical.topAfterHairline)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.bottom, vertical.bottom)
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
