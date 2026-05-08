import PhathomCore
import SwiftData
import SwiftUI

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

    @State private var filterKind: ContentKind?
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

    init(deepLinkItemID: Binding<UUID?> = .constant(nil)) {
        _deepLinkItemID = deepLinkItemID
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyLibraryMessage: String {
        trimmedQuery.isEmpty ? "No items yet" : "No matches"
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

    private var shouldShowManualKickoff: Bool {
        manualKickoffItemCount > 0
    }

    /// Number of skeleton rows shown in "Related by tags" while the expanded flow is running. Falls
    /// back to a small constant so placeholders are visible even when Stage 1 had no adjacent set.
    private var skeletonCount: Int {
        max(displayedAdjacent.count, sections.adjacent.count, 3)
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                librarySection

                if !displayedAdjacent.isEmpty || isDeepRanking {
                    relatedByTagsSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppPalette.background)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let item = items.first(where: { $0.id == id }) {
                    DetailView(item: item) { selectedID in
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
            .searchable(text: $searchText, prompt: "Search title, tags, source text")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Phathom")
                        .font(.headline)
                        .foregroundStyle(AppPalette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsContent()
                            .navigationTitle("Settings")
                    } label: {
                        Image(systemName: isModelHealthyForIndicator ? "gearshape.fill" : "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityValue(isModelHealthyForIndicator ? "AI model ready" : "AI model needs attention")
                }
            }
        }
        .task(id: SearchSignature(
            query: searchText,
            kind: filterKind,
            libraryRevision: Self.libraryRevision(for: items)
        )) {
            await recomputeSections()
        }
        .onChange(of: searchText) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: filterKind) { _, _ in
            deepRankedAdjacent = nil
        }
        .onChange(of: sections.adjacent.map(\.id)) { _, _ in
            deepRankedAdjacent = nil
        }
        .onAppear {
            refreshModelIndicator()
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
    }

    @ViewBuilder
    private var librarySection: some View {
        Section {
            if sections.matching.isEmpty {
                Text(emptyLibraryMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(sections.matching, id: \.id) { item in
                    NavigationLink(value: item.id) {
                        ContentCardRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            archiveFromLibrary(item: item)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
            }

            if canDiveDeeper {
                diveDeeperFooter
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        } header: {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Library")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if shouldShowManualKickoff {
                        Button {
                            runManualKickoff()
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppPalette.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start queued and needs attention processing")
                        .accessibilityHint("Process \(manualKickoffItemCount) item\(manualKickoffItemCount == 1 ? "" : "s") now")
                    }
                }
                FilterPills(selected: $filterKind)
            }
            .textCase(nil)
            .padding(.bottom, 4)
        }
    }

    private var diveDeeperFooter: some View {
        Button {
            Task { await runDiveDeeper() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Dive deeper")
                    .font(.subheadline.weight(.semibold))
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
            if isDeepRanking {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    rankingPlaceholder
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(displayedAdjacent, id: \.id) { item in
                    NavigationLink(value: item.id) {
                        ContentCardRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            archiveFromLibrary(item: item)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
            }
        } header: {
            Text("Related by tags")
                .font(.headline)
                .foregroundStyle(AppPalette.textPrimary)
                .textCase(nil)
                .padding(.bottom, 4)
        }
    }

    /// Skeleton card matching `ContentCardRow.card` chrome — same affordance as `RelatedItemsSheet`.
    private var rankingPlaceholder: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 76 * 0.15)
                .fill(AppPalette.surfaceNested)
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 8) {
                skeletonLine(width: nil)
                skeletonLine(width: nil, trailing: 24)
                skeletonLine(width: 140)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        // Debounce so rapid keystrokes don't run bucketing for every intermediate value.
        // Skip the delay for the very first run so the list isn't briefly empty on appear.
        if sectionsLoaded {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
        }
        let snapshot = items
        let query = searchText
        let kind = filterKind
        let computed = LibrarySearchService.bucket(query: query, items: snapshot, filterKind: kind)
        if Task.isCancelled { return }
        sections = computed
        sectionsLoaded = true
    }

    private func runDiveDeeper() async {
        guard ModelManager.hasReadableSelection else { return }
        let querySnapshot = searchText
        let kindSnapshot = filterKind
        let sectionsSnapshot = sections
        let allItemsSnapshot = items

        isDeepRanking = true
        let ranked = await LibrarySearchService.diveDeeper(
            query: querySnapshot,
            sections: sectionsSnapshot,
            allItems: allItemsSnapshot,
            filterKind: kindSnapshot
        )
        // If the user changed the query or filter while ranking, drop the result rather than apply
        // it to a different section.
        guard searchText == querySnapshot, filterKind == kindSnapshot else {
            isDeepRanking = false
            return
        }
        deepRankedAdjacent = ranked
        isDeepRanking = false
    }

    private func archiveFromLibrary(item: ContentItem) {
        ArchiveRetention.archive(item)
        try? modelContext.save()
        NotificationCenter.default.post(
            name: .phathomDidArchiveItem,
            object: nil,
            userInfo: ["itemID": item.id, "switchToLibrary": true]
        )
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

    private func runManualKickoff() {
        if !queuedItems.isEmpty {
            BackgroundPipeline.scheduleForegroundDrain()
            BackgroundPipeline.scheduleIngest()
        }
        for item in failedItems {
            _ = ProcessingRecovery.retryFailedItemIfNeeded(item, modelContext: modelContext)
        }
    }

    /// Fingerprint of searchable fields + tags so bucketing reruns when content changes even if the
    /// library count stays the same.
    private static func libraryRevision(for items: [ContentItem]) -> Int {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.kind)
            hasher.combine(item.title ?? "")
            hasher.combine(item.displayTitle)
            hasher.combine(item.displayHost ?? "")
            hasher.combine(item.originalURL?.absoluteString ?? "")
            hasher.combine(item.mediaDescription ?? "")
            let raw = item.rawText ?? ""
            hasher.combine(raw.count)
            if !raw.isEmpty {
                hasher.combine(String(raw.prefix(4_096)))
            }
            for tag in item.tags {
                hasher.combine(tag.name)
            }
        }
        return hasher.finalize()
    }
}

/// Composite key for the bucketing `.task(id:)`: query, kind filter, and a content revision so edits
/// to titles, bodies, or tags refresh results without requiring a count change.
private struct SearchSignature: Equatable {
    let query: String
    let kind: ContentKind?
    let libraryRevision: Int
}

#Preview("Library") {
    LibraryTab()
        .modelContainer(PreviewModel.makeContainer())
}
