import PhathomCore
import PhathomInference
import SwiftData
import SwiftUI

private enum LibraryScrollAnchor {
    static let top = "libraryScrollTop"
}

struct LibraryTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Binding var deepLinkItemID: UUID?

    @Query(
        filter: #Predicate<ContentItem> { !$0.isArchived },
        sort: \.createdAt,
        order: .reverse
    )
    private var items: [ContentItem]

    @Query(sort: \PhathomCore.Category.name, order: .forward)
    private var categories: [PhathomCore.Category]

    @AppStorage(LibraryFilterStorage.kindKey) private var filterKindRaw: String = ""
    @AppStorage(LibraryFilterStorage.statusKey) private var filterStatusRaw: String = ""
    @AppStorage(LibraryFilterStorage.categoryKey) private var filterCategoryRaw: String = ""

    private var sortedCategoryNames: [String] {
        categories
            .sorted {
                CategoryDisplayFormatter.displayName($0.name).localizedCaseInsensitiveCompare(
                    CategoryDisplayFormatter.displayName($1.name)
                ) == .orderedAscending
            }
            .map(\.name)
    }

    private var decodedFilterKinds: Set<ContentKind>? {
        LibraryFilterCodec.decodeKinds(filterKindRaw)
    }

    private var decodedFilterStatuses: Set<ReadStatus>? {
        LibraryFilterCodec.decodeStatuses(filterStatusRaw)
    }

    private var decodedFilterCategories: Set<String>? {
        LibraryFilterCodec.decodeCategories(filterCategoryRaw)
    }

    private var swipeFileSheetPresented: Binding<Bool> {
        Binding(
            get: { pendingSwipeItemID != nil },
            set: {
                if !$0 { pendingSwipeItemID = nil }
            }
        )
    }

    @State private var searchText = ""
    @State private var navPath = NavigationPath()
    @State private var isModelHealthyForIndicator = false

    /// Stage 1 result. Recomputed via `.task(id:)` with a ~150 ms debounce so per-keystroke work is
    /// off the body re-evaluation path even on large libraries.
    @State private var sections: LibrarySearchService.Sections = .empty
    /// `true` once the Stage 1 task has produced its first result for the current `searchText` /
    /// `filterKind` pair. Until then we keep showing the previous list to avoid a blank flash.
    @State private var sectionsLoaded = false
    /// Llama-reranked adjacent. Non-nil only after a successful "Dive deeper" run for the current
    /// query; cleared whenever the query or filter changes so a stale order can never be shown.
    @State private var deepRankedAdjacent: [ContentItem]? = nil
    @State private var isDeepRanking = false
    /// Bumped when library content may affect search bucketing (`LibraryContentChangeNotifier` + `items.count`).
    /// Avoids hashing every item on every SwiftUI body evaluation (see `SearchSignature`).
    @State private var libraryContentRevision: Int = 0
    @State private var editMode: PhathomEditMode = .inactive
    @State private var selectedItemIDs = Set<UUID>()

    @State private var pendingSwipeItemID: UUID?
    @State private var swipeCategoryHandled = false

    @State private var showBulkCategoryPicker = false
    @State private var bulkCategoryHandled = false
    @State private var bulkPendingItemIDs = Set<UUID>()

    @State private var userPaused = PipelineUserPause.isPaused
    @State private var foregroundDrainActive = BackgroundPipeline.isForegroundDrainActive
    @State private var isPauseInFlight = false

    @State private var isSearchActive = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isShowingSettings = false

    @State private var focusOutcomeItem: ContentItem?
    @State private var focusTakeawayItem: ContentItem?
    @State private var focusRevisitItem: ContentItem?
    @State private var focusReferenceTargetItem: ContentItem?
    @State private var pendingFocusReferenceCategory = false
    @State private var focusReferenceCategoryHandled = false
    @State private var focusOutcomeSkipReleaseOnDismiss = false
    @State private var focusSwapIncomingItem: ContentItem?

    private static let inFlightStatuses: Set<ProcessingStatus> = [
        .scraping, .embedding, .summarizing, .extracting, .tagging,
    ]

    init(deepLinkItemID: Binding<UUID?> = .constant(nil)) {
        _deepLinkItemID = deepLinkItemID
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchFilteredAtRest: Bool {
        !trimmedQuery.isEmpty && !isSearchActive
    }

    private var filtersActive: Bool {
        !LibraryFilterCodec.isKindPassThrough(filterKindRaw)
            || !LibraryFilterCodec.isStatusPassThrough(filterStatusRaw)
            || !LibraryFilterCodec.isCategoryPassThrough(filterCategoryRaw)
    }

    /// Non-archived library pool with no kind/status/category filters (for filter-empty vs true-empty).
    private var unfilteredLibraryCount: Int {
        TagRelationService.itemsFilteredByKindStatusAndCategory(items: items).count
    }

    private func sanitizeCategoryFilterIfNeeded() {
        let sanitized = LibraryFilterCodec.sanitizeCategoryRaw(filterCategoryRaw, validNames: sortedCategoryNames)
        if sanitized != filterCategoryRaw {
            filterCategoryRaw = sanitized
        }
    }

    /// Adjacent rows shown in the "Related by tags" section: deep-ranked when available, otherwise
    /// the Stage 1 order from the service.
    private var displayedAdjacent: [ContentItem] {
        deepRankedAdjacent ?? sections.adjacent
    }

    /// Minimum query length before "Dive deeper" appears. Avoids running the expanded flow on
    /// 1-2 char inputs where semantic expansion produces noise.
    private static let diveDeeperMinQuery = 3

    private var canDiveDeeper: Bool {
        sectionsLoaded
            && trimmedQuery.count >= Self.diveDeeperMinQuery
            && deepRankedAdjacent == nil
            && !isDeepRanking
            && ModelManager.hasReadableSelection
    }

    private var queuedItems: [ContentItem] {
        items.filter { !$0.isArchived && $0.status == .pending }
    }

    private var failedItems: [ContentItem] {
        items.filter { !$0.isArchived && $0.status == .failed }
    }

    private var manualKickoffItemCount: Int {
        queuedItems.count + failedItems.count
    }

    private var inFlightItems: [ContentItem] {
        items.filter { !$0.isArchived && Self.inFlightStatuses.contains($0.status) }
    }

    private var hasInFlightProcessing: Bool {
        !inFlightItems.isEmpty
    }

    private var hasPauseStoppingDetail: Bool {
        items.contains { item in
            !item.isArchived
                && item.processingDetail == ProcessingStatusCopy.pauseStoppingDetail
        }
    }

    private var isPipelineControlSettling: Bool {
        isPauseInFlight || hasPauseStoppingDetail
    }

    private var pipelineControl: LibraryPipelineControl? {
        if userPaused { return .resume }
        if hasInFlightProcessing || foregroundDrainActive { return .pause }
        if manualKickoffItemCount > 0 { return .resume }
        return nil
    }

    /// Number of skeleton rows shown in "Related by tags" while the expanded flow is running. Falls
    /// back to a small constant so placeholders are visible even when Stage 1 had no adjacent set.
    private var skeletonCount: Int {
        max(displayedAdjacent.count, sections.adjacent.count, 3)
    }

    /// Shared list content for both Select-mode `List(selection:)` and plain `List` when browsing.
    @ViewBuilder
    private var libraryListSections: some View {
        libraryMatchingSection
        if !displayedAdjacent.isEmpty || isDeepRanking {
            relatedByTagsSection
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                ScrollViewReader { scrollProxy in
                    Group {
                        if editMode == .active {
                            List(selection: $selectedItemIDs) {
                                libraryScrollChrome
                                libraryListSections
                            }
                        } else {
                            List {
                                libraryScrollChrome
                                libraryListSections
                            }
                        }
                    }
                    .phathomEditMode($editMode)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)
                    .background(AppPalette.background)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        libraryBulkActionsBar
                    }
                    .onChange(of: isSearchActive) { _, active in
                        guard active else { return }
                        scrollProxy.scrollTo(LibraryScrollAnchor.top, anchor: .top)
                        isSearchFieldFocused = true
                    }
                }

                if isSearchActive {
                    PinnedLibrarySearchBar(
                        text: $searchText,
                        onClose: cancelSearch,
                        isFieldFocused: $isSearchFieldFocused
                    )
                }
            }
            .navigationDestination(for: UUID.self) { id in
                libraryDetailDestination(for: id)
            }
            #if os(iOS)
            .navigationDestination(isPresented: $isShowingSettings) {
                SettingsContent()
            }
            #endif
            .phathomHideNavigationBar()
        }
        .task(id: SearchSignature(
            query: searchText,
            kindRaw: filterKindRaw,
            statusRaw: filterStatusRaw,
            categoryRaw: filterCategoryRaw,
            contentRevision: libraryContentRevision
        )) {
            await recomputeSections()
        }
        .onChange(of: searchText) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: filterKindRaw) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: filterStatusRaw) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: filterCategoryRaw) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: sections.adjacent.map(\.id)) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: items.count) { _, _ in
            libraryContentRevision &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomLibraryContentDidChange)) { _ in
            libraryContentRevision &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomPipelinePauseDidChange)) { _ in
            refreshPipelineControlState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomForegroundDrainActiveDidChange)) { _ in
            refreshPipelineControlState()
        }
        .onAppear {
            refreshModelIndicator()
            refreshPipelineControlState()
            sanitizeCategoryFilterIfNeeded()
        }
        .onChange(of: sortedCategoryNames) { _, _ in
            sanitizeCategoryFilterIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomModelAvailabilityDidChange)) { _ in
            refreshModelIndicator()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshModelIndicator()
        }
        .onChange(of: deepLinkItemID) { _, newValue in
            guard let id = newValue else { return }
            navPath.append(id)
            deepLinkItemID = nil
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedItemIDs = []
            }
        }
        .sheet(isPresented: swipeFileSheetPresented, onDismiss: swipeCategorySheetOnDismiss) {
            CategoryPicker { picked in
                swipeCategoryHandled = true
                applySwipeCategoryPick(picked)
            }
        }
        .sheet(isPresented: $showBulkCategoryPicker, onDismiss: bulkCategorySheetOnDismiss) {
            CategoryPicker { picked in
                bulkCategoryHandled = true
                applyBulkCategoryPick(picked)
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
        .sheet(item: $focusSwapIncomingItem) { incoming in
            FocusSwapSheet(
                incomingItem: incoming,
                entries: focusActiveEntriesForSwap,
                onSwap: { entry in
                    performFocusSwap(releasing: entry, adding: incoming)
                    focusSwapIncomingItem = nil
                },
                onCancel: {
                    focusSwapIncomingItem = nil
                }
            )
        }
    }

    @ViewBuilder
    private var libraryBulkActionsBar: some View {
        if editMode == .active, !selectedItemIDs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(selectedItemIDs.count) selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.textPrimary)
                    .accessibilityAddTraits(.updatesFrequently)

                HStack(spacing: 12) {
                    Menu {
                        ForEach(ReadStatus.allCases, id: \.self) { status in
                            Button {
                                bulkSetReadStatus(status)
                            } label: {
                                Label(
                                    ReadStatusPresentation.swipeActionLabel(for: status),
                                    systemImage: ReadStatusPresentation.symbolName(for: status)
                                )
                            }
                        }
                    } label: {
                        Label {
                            Text("Mark as…")
                                .font(.subheadline.weight(.semibold))
                                .phathomCapsuleCTALabel()
                        } icon: {
                            Image(systemName: "square.and.pencil")
                        }
                        .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.surfaceNested)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Change reading status for selected items")

                    Button {
                        bulkArchiveSelection()
                    } label: {
                        Label {
                            Text("Archive")
                                .font(.subheadline.weight(.semibold))
                                .phathomCapsuleCTALabel()
                        } icon: {
                            Image(systemName: "archivebox")
                        }
                        .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.surfaceNested)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .tint(.orange)
                    .accessibilityHint("Archive selected items to Recently Deleted")
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 12)
            .background(AppPalette.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppPalette.textTertiary.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, 8)
        }
    }

    /// Actions row + editorial title + filters — unified scroll with gallery rows (§3.1).
    @ViewBuilder
    private var libraryScrollChrome: some View {
        Section {
            libraryActionsRow
                .id(LibraryScrollAnchor.top)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .opacity(isSearchActive ? 0 : 1)
                .allowsHitTesting(!isSearchActive)
                .accessibilityHidden(isSearchActive)

            VStack(alignment: .leading, spacing: 0) {
                EditorialScreenTitle(title: "Library")
                LibraryFilterBar(
                    filterKindRaw: $filterKindRaw,
                    filterStatusRaw: $filterStatusRaw,
                    filterCategoryRaw: $filterCategoryRaw,
                    categories: categories
                )
            }
            .textCase(nil)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .opacity(isSearchActive ? 0.55 : 1)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    /// Top actions: Select/Done · Pipeline · Search · Settings (§3.1, §3.2.1).
    private var libraryActionsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            if editMode == .active {
                Button {
                    editMode = .inactive
                    selectedItemIDs = []
                } label: {
                    Text("Done")
                        .font(.system(size: 17))
                        .phathomToolbarTextLabel()
                }
                .foregroundStyle(AppPalette.accent)
                .buttonStyle(.plain)
                .accessibilityLabel("Done selecting library items")
            } else {
                Button {
                    editMode = .active
                } label: {
                    Text("Select")
                        .font(.system(size: 17))
                        .phathomToolbarTextLabel()
                }
                .foregroundStyle(AppPalette.accent)
                .buttonStyle(.plain)
                .accessibilityLabel("Select library items")
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                if let control = pipelineControl {
                    LibraryPipelineControlButton(
                        control: control,
                        isSettling: isPipelineControlSettling,
                        resumeAccessibilityLabel: resumeAccessibilityLabel,
                        resumeAccessibilityHint: resumeAccessibilityHint,
                        onPause: runPipelinePause,
                        onResume: runPipelineResume
                    )
                }

                Button {
                    activateSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(isSearchFilteredAtRest ? AppPalette.accent : AppPalette.textSecondary)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
                .accessibilityValue(isSearchFilteredAtRest ? "Search filter active" : "")

                #if os(iOS)
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: isModelHealthyForIndicator ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityValue(isModelHealthyForIndicator ? "AI model ready" : "AI model needs attention")
                #endif
            }
            .offset(x: -8)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func activateSearch() {
        isSearchActive = true
    }

    private func cancelSearch() {
        isSearchFieldFocused = false
        isSearchActive = false
    }

    @ViewBuilder
    private var libraryEmptyState: some View {
        if !trimmedQuery.isEmpty {
            Text("No matches")
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if filtersActive, unfilteredLibraryCount > 0 {
            EditorialTwoTierEmptyState(
                title: "No items match these filters",
                hint: "Try changing Type, Status or Category."
            )
            .padding(.vertical, AppSpacing.galleryRowVertical)
            .padding(.bottom, 24)
        } else {
            Text("No items yet")
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        }
    }

    @ViewBuilder
    private var libraryMatchingSection: some View {
        Section {
            if sections.matching.isEmpty {
                libraryEmptyState
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.screenHorizontal, bottom: 0, trailing: AppSpacing.screenHorizontal))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(sections.matching, id: \.id) { item in
                    libraryItemRow(
                        item: item,
                        showsBottomHairline: !isLastMatchingGalleryRow(itemID: item.id)
                    )
                }
            }

            if canDiveDeeper {
                diveDeeperFooter
                    .listRowInsets(EdgeInsets(top: 12, leading: AppSpacing.screenHorizontal, bottom: 12, trailing: AppSpacing.screenHorizontal))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .opacity(isSearchActive ? 0.55 : 1)
    }

    private func isLastMatchingGalleryRow(itemID: UUID) -> Bool {
        guard let last = sections.matching.last, last.id == itemID else { return false }
        return !canDiveDeeper
    }
    private var diveDeeperFooter: some View {
        Button {
            Task { await runDiveDeeper() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Dive deeper")
                    .font(.subheadline.weight(.semibold))
                    .phathomCapsuleCTALabel()
            }
            .foregroundStyle(AppPalette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Use AI to find related items by tag")
    }

    @ViewBuilder
    private var relatedByTagsSection: some View {
        Section {
            Text("Related by tags")
                .font(.headline)
                .foregroundStyle(AppPalette.textPrimary)
                .textCase(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 8, leading: AppSpacing.screenHorizontal, bottom: 4, trailing: AppSpacing.screenHorizontal))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if isDeepRanking {
                ForEach(0..<skeletonCount, id: \.self) { index in
                    rankingPlaceholder
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .overlay(alignment: .bottom) {
                            if index < skeletonCount - 1 {
                                Rectangle()
                                    .fill(AppPalette.hairline)
                                    .frame(height: 1)
                                    .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }
                }
            } else {
                ForEach(displayedAdjacent, id: \.id) { item in
                    libraryItemRow(
                        item: item,
                        showsBottomHairline: item.id != displayedAdjacent.last?.id
                    )
                }
            }
        }
        .opacity(isSearchActive ? 0.55 : 1)
    }
    /// Skeleton row matching gallery hairline layout while deep ranking runs.
    private var rankingPlaceholder: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: AppSpacing.thumbCornerRadius)
                .fill(AppPalette.surfaceNested)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                skeletonLine(width: nil)
                skeletonLine(width: nil, trailing: 24)
                skeletonLine(width: 140)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(.vertical, AppSpacing.galleryRowVertical)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Re-ranking related item")
        .accessibilityAddTraits(.updatesFrequently)
    }
    private func skeletonLine(width: CGFloat?, trailing: CGFloat = 0) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppPalette.surfaceNested)
            .frame(width: width, height: 14)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .padding(.trailing, trailing)
            .accessibilityHidden(true)
    }

    private func recomputeSections() async {
        // Debounce non-empty search so rapid keystrokes don't run bucketing every intermediate value.
        // Empty query: no delay (filter toggles stay snappy). First run: no delay so list isn't empty on appear.
        let queryNonempty = !trimmedQuery.isEmpty
        if sectionsLoaded, queryNonempty {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
        }
        let snapshot = items
        let query = searchText
        let computed = LibrarySearchService.bucket(
            query: query,
            items: snapshot,
            filterKinds: decodedFilterKinds,
            filterStatuses: decodedFilterStatuses,
            filterCategories: decodedFilterCategories
        )
        if Task.isCancelled { return }
        sections = computed
        sectionsLoaded = true
    }

    private func runDiveDeeper() async {
        guard ModelManager.hasReadableSelection else { return }
        let querySnapshot = searchText
        let kindRawSnapshot = filterKindRaw
        let statusRawSnapshot = filterStatusRaw
        let categoryRawSnapshot = filterCategoryRaw
        let sectionsSnapshot = sections
        let allItemsSnapshot = items

        isDeepRanking = true
        let ranked = await LibrarySearchService.diveDeeper(
            query: querySnapshot,
            sections: sectionsSnapshot,
            allItems: allItemsSnapshot,
            filterKinds: LibraryFilterCodec.decodeKinds(kindRawSnapshot),
            filterStatuses: LibraryFilterCodec.decodeStatuses(statusRawSnapshot),
            filterCategories: LibraryFilterCodec.decodeCategories(categoryRawSnapshot)
        )
        // If the user changed the query or any filter while ranking, drop the result rather than
        // apply it to a different section.
        guard searchText == querySnapshot,
              filterKindRaw == kindRawSnapshot,
              filterStatusRaw == statusRawSnapshot,
              filterCategoryRaw == categoryRawSnapshot
        else {
            isDeepRanking = false
            return
        }
        deepRankedAdjacent = ranked
        isDeepRanking = false
    }

    private func archiveItems(_ toArchive: [ContentItem]) {
        guard !toArchive.isEmpty else { return }
        let ids = toArchive.map(\.id)
        for item in toArchive {
            ArchiveRetention.archive(item, in: modelContext)
        }
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        ArchiveRetention.notifyProcessingCancelAfterArchiveCommitted(itemIDs: ids)
        NotificationCenter.default.post(
            name: .phathomDidArchiveItem,
            object: nil,
            userInfo: PhathomArchiveNotification.userInfo(itemIDs: ids)
        )
    }

    private func archiveFromLibrary(item: ContentItem) {
        archiveItems([item])
    }

    private var focusActiveEntriesForSwap: [FocusEntry] {
        (try? FocusStackService.activeEntries(in: modelContext)) ?? []
    }

    private func focusAtCapacity(for item: ContentItem) -> Bool {
        guard !item.isArchived else { return false }
        guard !FocusStackService.isInFocus(item) else { return false }
        guard let canAdd = try? FocusStackService.canAddWithoutSwap(in: modelContext) else { return false }
        return !canAdd
    }

    private func addToFocusFromLibrary(_ item: ContentItem) {
        guard !FocusStackService.isInFocus(item) else { return }
        if focusAtCapacity(for: item) {
            focusSwapIncomingItem = item
            return
        }
        do {
            try FocusStackService.addToFocus(item: item, in: modelContext)
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
        } catch FocusStackError.capFull {
            focusSwapIncomingItem = item
        } catch {
            return
        }
    }

    private func performFocusSwap(releasing entry: FocusEntry, adding item: ContentItem) {
        do {
            try FocusStackService.releaseForSwap(entry: entry, in: modelContext)
            try FocusStackService.addToFocus(item: item, in: modelContext)
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
        } catch {
            return
        }
    }

    private func removeFromFocusFromLibrary(_ item: ContentItem) {
        do {
            try FocusStackService.removeFromFocus(item: item, in: modelContext)
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
        } catch {
            return
        }
    }

    private func beginDoneInFocus(_ item: ContentItem) {
        focusOutcomeSkipReleaseOnDismiss = false
        focusOutcomeItem = item
    }

    @ViewBuilder
    private func libraryFocusContextMenu(for item: ContentItem) -> some View {
        if FocusStackService.isInFocus(item) {
            Button {
                beginDoneInFocus(item)
            } label: {
                Label("Done in Focus", systemImage: "checkmark.circle")
            }
            Button {
                removeFromFocusFromLibrary(item)
            } label: {
                Label("Remove from Focus", systemImage: "scope")
            }
        } else {
            Button {
                addToFocusFromLibrary(item)
            } label: {
                Label("Add to Focus", systemImage: "scope")
            }
        }
    }

    @ViewBuilder
    private func libraryItemRow(item: ContentItem, showsBottomHairline: Bool) -> some View {
        if editMode == .inactive {
            Button {
                navPath.append(item.id)
            } label: {
                GalleryListRow(item: item, showsBottomHairline: showsBottomHairline)
            }
            .buttonStyle(.plain)
            .contextMenu {
                libraryFocusContextMenu(for: item)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                readStatusSwipeButtons(for: item)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    archiveFromLibrary(item: item)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(.orange)
            }
        } else {
            GalleryListRow(item: item, showsBottomHairline: showsBottomHairline)
                .tag(item.id)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }
    private func resolvedSelectedItems() -> [ContentItem] {
        selectedItemIDs.compactMap { id in items.first { $0.id == id } }
    }

    private func bulkSetReadStatus(_ status: ReadStatus) {
        let resolved = resolvedSelectedItems()
        guard !resolved.isEmpty else { return }
        if status == .filed {
            bulkPendingItemIDs = Set(resolved.map(\.id))
            bulkCategoryHandled = false
            showBulkCategoryPicker = true
            return
        }
        ContentItem.applyReadStatus(status, to: resolved, modelContext: modelContext)
        selectedItemIDs = []
    }

    private func bulkArchiveSelection() {
        let resolved = resolvedSelectedItems()
        guard !resolved.isEmpty else { return }
        archiveItems(resolved)
        selectedItemIDs = []
    }

    /// Leading-swipe buttons: only the two statuses the item is **not** currently in,
    /// in the canonical `new -> read -> filed` order. Mirrors iOS Mail's leading-swipe affordance
    /// while letting the user pick any non-current status in one gesture.
    @ViewBuilder
    private func readStatusSwipeButtons(for item: ContentItem) -> some View {
        let current = item.readState
        ForEach(ReadStatus.allCases.filter { $0 != current }, id: \.self) { target in
            Button {
                if target == .filed {
                    pendingSwipeItemID = item.id
                    swipeCategoryHandled = false
                } else {
                    setReadStatus(target, for: item)
                }
            } label: {
                Label(
                    ReadStatusPresentation.swipeActionLabel(for: target),
                    systemImage: ReadStatusPresentation.symbolName(for: target)
                )
            }
            .tint(ReadStatusPresentation.swipeTint(for: target))
        }
    }

    private func setReadStatus(_ status: ReadStatus, for item: ContentItem) {
        item.applyReadStatus(status, modelContext: modelContext)
    }

    private func refreshModelIndicator() {
        ModelManager.validateSelection()
        let selection = ModelManager.selectionDisplayState()
        let hasReadySelection: Bool
        switch selection {
        case .ready:
            hasReadySelection = true
        case .noSelection, .missingFile:
            hasReadySelection = false
        }
        isModelHealthyForIndicator = hasReadySelection && !ModelManager.didLastLoadFail
    }

    private var resumeAccessibilityLabel: String {
        userPaused ? "Resume processing" : "Start queued and needs attention processing"
    }

    private var resumeAccessibilityHint: String {
        if userPaused {
            return "Resume ingest and analysis for paused items"
        }
        return "Process \(manualKickoffItemCount) item\(manualKickoffItemCount == 1 ? "" : "s") now"
    }

    private func refreshPipelineControlState() {
        userPaused = PipelineUserPause.isPaused
        foregroundDrainActive = BackgroundPipeline.isForegroundDrainActive
    }

    private func runPipelinePause() {
        guard !isPauseInFlight else { return }
        isPauseInFlight = true
        Task {
            await BackgroundPipeline.pauseAllProcessing()
            await MainActor.run {
                isPauseInFlight = false
                refreshPipelineControlState()
            }
        }
    }

    private func runPipelineResume() {
        guard !isPipelineControlSettling else { return }
        PipelineUserPause.setPaused(false)
        refreshPipelineControlState()
        BackgroundPipeline.scheduleAll()
        BackgroundPipeline.scheduleForegroundDrain()
        for item in failedItems {
            _ = ProcessingRecovery.retryFailedItemIfNeeded(item, modelContext: modelContext)
        }
    }

    private func applySwipeCategoryPick(_ category: PhathomCore.Category?) {
        guard let id = pendingSwipeItemID, let row = items.first(where: { $0.id == id }) else { return }
        ContentItem.applyFiled(category: category, to: [row], modelContext: modelContext)
    }

    private func swipeCategorySheetOnDismiss() {
        let targetID = pendingSwipeItemID
        let handled = swipeCategoryHandled
        pendingSwipeItemID = nil
        swipeCategoryHandled = false
        guard !handled, let targetID, let row = items.first(where: { $0.id == targetID }) else { return }
        ContentItem.applyFiled(category: nil, to: [row], modelContext: modelContext)
    }

    private func applyBulkCategoryPick(_ category: PhathomCore.Category?) {
        let resolvedIDs = bulkPendingItemIDs
        let resolved = resolvedIDs.compactMap { id in items.first(where: { $0.id == id }) }
        guard !resolved.isEmpty else {
            bulkPendingItemIDs.removeAll()
            selectedItemIDs = []
            return
        }
        ContentItem.applyFiled(category: category, to: resolved, modelContext: modelContext)
        bulkPendingItemIDs.removeAll()
        selectedItemIDs = []
    }

    private func bulkCategorySheetOnDismiss() {
        let ids = bulkPendingItemIDs
        let handled = bulkCategoryHandled
        bulkCategoryHandled = false
        if handled {
            bulkPendingItemIDs.removeAll()
            return
        }
        let resolved = ids.compactMap { id in items.first(where: { $0.id == id }) }
        bulkPendingItemIDs.removeAll()
        guard !resolved.isEmpty else {
            selectedItemIDs = []
            return
        }
        ContentItem.applyFiled(category: nil, to: resolved, modelContext: modelContext)
        selectedItemIDs = []
    }

    @ViewBuilder
    private func libraryDetailDestination(for id: UUID) -> some View {
        if let item = items.first(where: { $0.id == id }) {
            LibraryDetailRoute(item: item) { selectedID in
                if !navPath.isEmpty { navPath.removeLast() }
                navPath.append(selectedID)
            }
        } else {
            Text("This item is not in your library.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

/// Composite key for the bucketing `.task(id:)`: query, filters, and `libraryContentRevision`
/// (bumped via `LibraryContentChangeNotifier` and `items.count` so edits refresh without hashing the library on every body eval).
private struct SearchSignature: Equatable {
    let query: String
    let kindRaw: String
    let statusRaw: String
    let categoryRaw: String
    let contentRevision: Int
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
