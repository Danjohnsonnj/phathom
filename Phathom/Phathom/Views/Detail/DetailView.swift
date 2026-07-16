import PhathomCore
import PhathomCoreMarkdown
import PhathomInference
import SwiftData
import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct DetailView: View {
    @Bindable var item: ContentItem
    /// Optional handler invoked when the user picks a related item from the tag-tap sheet.
    /// `LibraryTab` supplies a handler that replaces its `NavigationPath` so the user lands on the
    /// chosen item's detail. Call sites without their own NavigationStack (preview, RecentlyDeletedView)
    /// can omit this; tapping a related item will simply dismiss the sheet.
    var onRelatedItemSelected: ((UUID) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.typographyScale) private var typographyScale

    @State private var sourceExpanded = false
    @State private var titleDraft: String = ""
    @State private var relatedSheetTag: Tag?
    @State private var isTagEditMode = false
    @State private var isTagEditorPresented = false
    @State private var tagEditorMode: TagEditSheetMode = .add
    @State private var tagEditorDraft = ""
    @State private var tagEditorErrorMessage: String?
    @State private var delaySummarizeDisable = false
    @State private var noteEditHighlight: Highlight?
    @State private var sourceWebSelectionActive = false
    @State private var sourceWebHighlightApplyToken = 0
    #if os(iOS)
    @State private var browserURL: IdentifiableURL?
    #endif
    @State private var pendingFileCategorySheet = false
    @State private var detailCategoryPickHandled = false
    @State private var isCategoryPickerPresented = false
    @State private var focusOutcomeItem: ContentItem?
    @State private var focusTakeawayItem: ContentItem?
    @State private var focusRevisitItem: ContentItem?
    @State private var focusReferenceTargetItem: ContentItem?
    @State private var pendingFocusReferenceCategory = false
    @State private var focusReferenceCategoryHandled = false
    @State private var focusOutcomeSkipReleaseOnDismiss = false
    @State private var isFocusSwapSheetPresented = false
    @State private var mediaPhotoPresentation: MediaPhotoViewerPresentation?
    @State private var cachedMediaUIImage: PlatformImage?
    @State private var mediaImageLoadAppearGeneration: Int = 0
    @State private var loadedMediaThumbnailCacheKey: String?
    #if os(iOS)
    @State private var isPresentingLinkShare = false
    @State private var isPresentingMarkdownShare = false
    @State private var markdownShareURL: URL?
    #else
    @State private var showMarkdownExporter = false
    @State private var markdownExportDocument = MarkdownExportDocument()
    @State private var markdownExportFilename = "article.md"
    #endif
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

    private var canExportMarkdown: Bool {
        guard item.kind == .web else { return false }
        guard let md = item.sourceMarkdown else { return false }
        return !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var linkShareItems: [Any] {
        if let shareURL { return [shareURL] }
        return [item.displayTitle]
    }

    private var itemUUID: UUID {
        item[keyPath: \ContentItem.id]
    }

    private var mediaThumbnailCacheKey: String {
        "\(itemUUID.uuidString)-\(item.thumbnailData?.count ?? 0)"
    }

    private func presentMediaPhotoViewerIfAvailable() {
        guard let image = cachedMediaUIImage else { return }
        mediaPhotoPresentation = MediaPhotoViewerPresentation(
            presentationID: UUID(),
            itemID: itemUUID,
            image: image,
            accessibilityLabel: mediaPhotoAccessibilityLabel
        )
    }

    private func dismissMediaPhotoViewer() {
        mediaPhotoPresentation = nil
    }

    private func invalidateMediaImageCache() {
        MediaDisplayImageCache.shared.remove(itemID: itemUUID)
        Task { await MediaDisplayImageLoader.invalidateGeneration(for: itemUUID) }
        loadedMediaThumbnailCacheKey = nil
        cachedMediaUIImage = nil
        dismissMediaPhotoViewer()
    }

    @MainActor
    private func loadCachedMediaImageIfNeeded() async {
        guard item.kind == .media else {
            cachedMediaUIImage = nil
            loadedMediaThumbnailCacheKey = nil
            return
        }

        let taskKey = mediaThumbnailCacheKey
        if cachedMediaUIImage != nil, loadedMediaThumbnailCacheKey == taskKey {
            return
        }

        guard let modelContainer = BackgroundPipeline.modelContainerOrNil() else {
            cachedMediaUIImage = nil
            loadedMediaThumbnailCacheKey = nil
            return
        }
        let image = await MediaDisplayImageLoader.loadDisplayImage(
            itemID: itemUUID,
            modelContainer: modelContainer,
            appearGeneration: mediaImageLoadAppearGeneration
        )
        cachedMediaUIImage = image
        loadedMediaThumbnailCacheKey = taskKey
    }

    private var mediaPhotoAccessibilityLabel: String {
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty || title == "Photo" ? "Photo" : title
    }

    private var heroImageForSection: PlatformImage? {
        item.kind == .media ? cachedMediaUIImage : nil
    }

    private var mediaViewPhotoHandler: (() -> Void)? {
        guard item.kind == .media else { return nil }
        return presentMediaPhotoViewerIfAvailable
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HeroSection(
                    item: item,
                    heroImage: heroImageForSection,
                    onViewPhoto: mediaViewPhotoHandler
                )

                VStack(alignment: .leading, spacing: 0) {
                    headerBlock

                    sourceContentSection
                        .detailSection(topHairline: true, vertical: .spaced)

                    readingStatusSection
                        .detailSection(topHairline: true, vertical: .compact)

                    focusSection
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
        .background(AppPalette.background)
        .phathomInlineNavigationTitle()
        .navigationBarBackButtonHidden(true)
        .phathomHideNavigationBar()
        .safeAreaInset(edge: .top, spacing: 0) {
            DetailPushNavBar {
                DetailOverflowMenu(
                    shareURL: shareURL,
                    fallbackTitle: item.displayTitle,
                    canExportMarkdown: canExportMarkdown,
                    onShareLink: presentLinkShare,
                    onExportMarkdown: prepareMarkdownExport
                )
            }
        }
        .onAppear {
            mediaImageLoadAppearGeneration &+= 1
            syncTitleDraftFromItem()
            ensureSourceContentHTMLIfNeeded()
            touchFocusEngagementIfNeeded()
        }
        .onChange(of: item.title) { _, _ in
            if !titleFocused { syncTitleDraftFromItem() }
        }
        .onChange(of: item.sourceMarkdown) { _, _ in
            ensureSourceContentHTMLIfNeeded()
        }
        .id(itemUUID)
        .background {
            Color.clear
                .task(id: mediaThumbnailCacheKey) {
                    await loadCachedMediaImageIfNeeded()
                }
        }
        .onChange(of: itemUUID) { _, _ in
            invalidateMediaImageCache()
        }
        .onChange(of: item.thumbnailData) { _, _ in
            invalidateMediaImageCache()
            Task { await loadCachedMediaImageIfNeeded() }
        }
        .phathomFullScreenPhotoCover(item: $mediaPhotoPresentation, onDismiss: {
            mediaPhotoPresentation = nil
        }) { presentation in
            MediaPhotoViewer(
                image: presentation.image,
                accessibilityLabel: presentation.accessibilityLabel
            )
        }
        .sheet(item: $relatedSheetTag) { tag in
            RelatedItemsSheet(sourceItem: item, tappedTag: tag) { selected in
                let id = selected.id
                relatedSheetTag = nil
                onRelatedItemSelected?(id)
            }
        }
        .sheet(isPresented: $isTagEditorPresented) {
            TagEditSheet(
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
        }
        #if os(iOS)
        .sheet(item: $browserURL) { SafariSheetView(url: $0.url) }
        #endif
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
        .focusOutcomeFlow(
            outcomeItem: $focusOutcomeItem,
            takeawayItem: $focusTakeawayItem,
            revisitItem: $focusRevisitItem,
            referenceTargetItem: $focusReferenceTargetItem,
            pendingReferenceCategory: $pendingFocusReferenceCategory,
            referenceCategoryHandled: $focusReferenceCategoryHandled,
            skipReleaseOnOutcomeDismiss: $focusOutcomeSkipReleaseOnDismiss
        )
        .sheet(isPresented: $isFocusSwapSheetPresented) {
            FocusSwapSheet(
                incomingItem: item,
                entries: focusActiveEntriesForSwap,
                onSwap: { entry in
                    performFocusSwap(releasing: entry)
                    isFocusSwapSheetPresented = false
                },
                onCancel: {
                    isFocusSwapSheetPresented = false
                }
            )
        }
        #if os(iOS)
        .sheet(isPresented: $isPresentingLinkShare) {
            ShareActivityViewController(items: linkShareItems) {
                isPresentingLinkShare = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingMarkdownShare) {
            if let markdownShareURL {
                ShareActivityViewController(items: [markdownShareURL]) {
                    isPresentingMarkdownShare = false
                }
                .ignoresSafeArea()
            }
        }
        #else
        .fileExporter(
            isPresented: $showMarkdownExporter,
            document: markdownExportDocument,
            contentType: UTType(filenameExtension: "md") ?? .plainText,
            defaultFilename: markdownExportFilename
        ) { _ in }
        #endif
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
                    .appTypography(.subsectionHeader)
                    .foregroundStyle(AppPalette.accent)
            }

            TextField(item.displayTitle, text: $titleDraft, axis: .vertical)
                .appTypography(.detailTitle)
                .foregroundStyle(AppPalette.textPrimary)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .focused($titleFocused)
                .onSubmit { commitTitleDraft() }
                .onChange(of: titleFocused) { _, isFocused in
                    if !isFocused { commitTitleDraft() }
                }

            Text(item.createdAt.formatted(Self.timestampFormat))
                .appTypography(.zoneSubtitle)
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
                    .appTypography(.zoneSubtitle)
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

    private func saveTagChanges(for sheet: TagEditSheetMode) {
        guard let normalized = TagNameNormalizer.normalize(tagEditorDraft) else {
            tagEditorErrorMessage = "Tag format invalid."
            return
        }
        var provenance = item.userAddedTagNames
        switch sheet {
        case .add:
            attachTagIfNeeded(named: normalized)
            provenance = TagProvenanceNormalizer.applyAdd(current: provenance, added: normalized)
        case let .edit(originalTagName):
            if normalized == originalTagName {
                dismissTagEditor()
                return
            }
            item.tags.removeAll(where: { $0.name == originalTagName })
            attachTagIfNeeded(named: normalized)
            provenance = TagProvenanceNormalizer.applyRename(
                current: provenance,
                from: originalTagName,
                to: normalized
            )
        }
        item.userAddedTagNames = TagProvenanceNormalizer.normalizeMany(provenance)
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

    private func deleteTag(for sheet: TagEditSheetMode) {
        guard case let .edit(originalTagName) = sheet else { return }
        item.tags.removeAll(where: { $0.name == originalTagName })
        item.userAddedTagNames = TagProvenanceNormalizer.normalizeMany(
            TagProvenanceNormalizer.applyDelete(current: item.userAddedTagNames, removed: originalTagName)
        )
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
        .accessibilityElement(children: .contain)
    }

    private var focusAtCapacity: Bool {
        guard !item.isArchived else { return false }
        guard !FocusStackService.isInFocus(item) else { return false }
        guard let canAdd = try? FocusStackService.canAddWithoutSwap(in: modelContext) else { return false }
        return !canAdd
    }

    private var focusActiveEntriesForSwap: [FocusEntry] {
        (try? FocusStackService.activeEntries(in: modelContext)) ?? []
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Focus")
                    .appTypography(.zoneHeader)
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer(minLength: 8)
                Toggle("", isOn: focusToggleBinding)
                    .labelsHidden()
                    .tint(AppPalette.accent)
                    .disabled(item.isArchived)
            }
            .frame(minHeight: 48, alignment: .center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Focus")
            .accessibilityValue(FocusStackService.isInFocus(item) ? "On" : "Off")
            .accessibilityHint(focusAtCapacity
                ? "Focus stack is full. Opens swap sheet to release one item before adding this article."
                : "Adds or removes this article from your Focus stack.")

            if let closureLine = focusClosureLine {
                Text(closureLine)
                    .appTypography(.zoneSubtitle)
                    .foregroundStyle(AppPalette.textSecondary)
                    .accessibilityLabel("Last Focus outcome: \(closureLine)")
            }
        }
    }

    private var focusClosureLine: String? {
        guard !FocusStackService.isInFocus(item) else { return nil }
        guard let latest = item.focusOutcomes.max(by: { $0.completedAt < $1.completedAt }) else {
            return nil
        }
        return FocusOutcomePresentation.closureLine(for: latest)
    }

    private var focusToggleBinding: Binding<Bool> {
        Binding(
            get: { FocusStackService.isInFocus(item) },
            set: { wantsFocus in
                applyFocusToggle(wantsFocus)
            }
        )
    }

    private func applyFocusToggle(_ wantsFocus: Bool) {
        if wantsFocus {
            guard !FocusStackService.isInFocus(item) else { return }
            if focusAtCapacity {
                isFocusSwapSheetPresented = true
                return
            }
            do {
                try FocusStackService.addToFocus(item: item, in: modelContext)
                try modelContext.save()
                LibraryContentChangeNotifier.postLibraryContentDidChange()
            } catch FocusStackError.capFull {
                isFocusSwapSheetPresented = true
            } catch {
                return
            }
        } else {
            guard FocusStackService.isInFocus(item) else { return }
            do {
                try FocusStackService.removeFromFocus(item: item, in: modelContext)
                try modelContext.save()
                LibraryContentChangeNotifier.postLibraryContentDidChange()
            } catch {
                return
            }
        }
    }

    private func touchFocusEngagementIfNeeded() {
        guard FocusStackService.isInFocus(item) else { return }
        FocusStackService.touchEngagement(item: item, in: modelContext)
        _ = DetailModelSave.save(modelContext, operation: "touchFocusEngagement")
    }

    private func performFocusSwap(releasing entry: FocusEntry) {
        do {
            try FocusStackService.releaseForSwap(entry: entry, in: modelContext)
            try FocusStackService.addToFocus(item: item, in: modelContext)
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
        } catch {
            return
        }
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
                .appTypography(.zoneHeader)
                .foregroundStyle(AppPalette.textPrimary)
            Spacer(minLength: 8)
            Text(categorySectionDisplayName)
                .appTypography(.zoneSubtitle)
                .foregroundStyle(AppPalette.textPrimary)
            Text("  ")
            Button {
                isCategoryPickerPresented = true
            } label: {
                Text("Edit")
                    .appTypography(.disclosureLabel)
                    .phathomToolbarTextLabel()
            }
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
                    .appTypography(.zoneHeader)
                    .foregroundStyle(AppPalette.textPrimary)

                Text(failedReasonDisplay)
                    .appTypography(.zoneSubtitle)
                    .foregroundStyle(AppPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    _ = ProcessingRecovery.retryFailedItemIfNeeded(item, modelContext: modelContext)
                } label: {
                    HairlineCapsuleButton(
                        title: "Retry",
                        foreground: AppPalette.textPrimary,
                        disabled: !ProcessingRecovery.canRetryFailed(item)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!ProcessingRecovery.canRetryFailed(item))

                if item.kind == .note, !noteHasRetryableText {
                    Text("This note has no text to analyze, so it cannot be retried.")
                        .appTypography(.meta)
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
                                .appTypography(.zoneSubtitle)
                                .foregroundStyle(AppPalette.textSecondary)
                            Text(line)
                                .appTypography(.zoneSubtitle)
                                .foregroundStyle(AppPalette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            } else if item.status == .failed {
                Text("Not available until processing succeeds.")
                    .appTypography(.zoneSubtitle)
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
                if FocusStackService.isInFocus(item) {
                    doneInFocusButton
                }
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

    private var doneInFocusButton: some View {
        Button {
            focusOutcomeSkipReleaseOnDismiss = false
            focusOutcomeItem = item
        } label: {
            HairlineCapsuleButton(
                title: "Done in Focus",
                foreground: AppPalette.accent
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Choose how to complete this item in Focus.")
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
            HairlineCapsuleButton(
                title: analyzeAgainButtonTitle,
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
            HairlineCapsuleButton(
                title: "Regenerate tags",
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
            HairlineCapsuleButton(title: "Restore to Library", foreground: Color.green.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private var archiveButton: some View {
        Button {
            ArchiveRetention.archive(item, in: modelContext)
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
            HairlineCapsuleButton(title: "Archive", foreground: AppPalette.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var sourceMarkdownForDisplay: String? {
        guard item.kind == .web, let md = item.sourceMarkdown, !md.isEmpty else { return nil }
        return md
    }

    private var collapsedSourceMarkdownMaxHeight: CGFloat {
        #if os(iOS)
        let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
        #else
        let lineHeight = NSFont.preferredFont(forTextStyle: .body).boundingRectForFont.size.height
        #endif
        return ceil(lineHeight * 8)
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
                .appTypography(.zoneSubtitle)
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
                                .appTypography(.zoneSubtitle)
                                .foregroundStyle(AppPalette.textSecondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        } else {
                            Text(desc)
                                .appTypography(.zoneSubtitle)
                                .foregroundStyle(AppPalette.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("No description generated")
                        .appTypography(.zoneSubtitle)
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
        FocusStackService.touchEngagement(item: item, in: modelContext)
        guard DetailModelSave.save(modelContext, operation: "createHighlight") == nil else { return }
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        noteEditHighlight = h
    }

    private static func encodeHighlightSegmentsJSON(_ segments: [HighlightMarkdownAnchor.Segment]) -> String? {
        guard !segments.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(segments) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func presentLinkShare() {
        #if os(iOS)
        isPresentingLinkShare = true
        #endif
    }

    private func prepareMarkdownExport() {
        guard canExportMarkdown, let md = item.sourceMarkdown else { return }
        let highlights = item.highlightsSortedByOffset.map {
            HighlightExportInput(
                sourceMarkdownOffset: $0.sourceMarkdownOffset,
                sourceMarkdownLength: $0.sourceMarkdownLength,
                sourceMarkdownSegmentsJSON: $0.sourceMarkdownSegmentsJSON,
                userNote: $0.userNote
            )
        }
        guard let export = AnnotatedMarkdownExporter.export(
            title: item.displayTitle,
            sourceURL: item.originalURL,
            sourceMarkdown: md,
            highlights: highlights
        ) else {
            return
        }

        #if os(iOS)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(export.suggestedFilename)
        do {
            try export.markdown.write(to: url, atomically: true, encoding: .utf8)
            markdownShareURL = url
            isPresentingMarkdownShare = true
        } catch {
            print("[DetailView] markdown export write failed: \(error)")
        }
        #else
        markdownExportDocument = MarkdownExportDocument(text: export.markdown)
        markdownExportFilename = export.suggestedFilename
        showMarkdownExporter = true
        #endif
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

    private var sourceContentSectionTitle: String {
        switch item.kind {
        case .web: "Article"
        case .note: "Note"
        case .media: "Summary"
        }
    }

    private var sourceContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sourceExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(sourceContentSectionTitle)
                        .appTypography(.zoneHeader)
                        .foregroundStyle(AppPalette.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(sourceExpanded ? "show less" : "show more")
                            .appTypography(.addNewAccentLabel)
                            .foregroundStyle(AppPalette.accent)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.accent)
                            .rotationEffect(.degrees(sourceExpanded ? 180 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                sourceExpanded
                    ? "\(sourceContentSectionTitle), expanded"
                    : "\(sourceContentSectionTitle), collapsed preview"
            )
            .accessibilityHint("Double tap to expand or collapse.")

            if item.kind == .note {
                if let raw = item.rawText, !raw.isEmpty {
                    if sourceExpanded {
                        Markdown(raw)
                            .markdownTheme(.phathomNote(scale: typographyScale))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Markdown(raw)
                            .markdownTheme(.phathomNote(scale: typographyScale))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(maxHeight: collapsedSourceMarkdownMaxHeight, alignment: .top)
                            .clipped()
                    }
                } else {
                    Text("No source text")
                        .appTypography(.zoneSubtitle)
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
                        bodyFontSizePx: typographyScale.scaled(16),
                        highlights: item.highlightsSortedByOffset,
                        collapsed: !sourceExpanded,
                        onCreateHighlight: { quotedText, hintOffset in
                            createHighlightFromWebView(
                                quotedText: quotedText,
                                hintOffset: hintOffset
                            )
                        },
                        onTapHighlight: { noteEditHighlight = $0 },
                        onTapLink: { url in
                            #if os(iOS)
                            browserURL = IdentifiableURL(url: url)
                            #else
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let md = sourceMarkdownForDisplay {
                if sourceExpanded {
                    Markdown(md)
                        .markdownTheme(.phathomNote(scale: typographyScale))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Markdown(md)
                        .markdownTheme(.phathomNote(scale: typographyScale))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: collapsedSourceMarkdownMaxHeight, alignment: .top)
                        .clipped()
                }
            } else if let raw = item.rawText, !raw.isEmpty {
                Group {
                    if sourceExpanded {
                        Text(raw)
                            .appTypography(.zoneSubtitle)
                            .foregroundStyle(AppPalette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text(raw)
                            .appTypography(.zoneSubtitle)
                            .foregroundStyle(AppPalette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("No source text")
                    .appTypography(.zoneSubtitle)
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
