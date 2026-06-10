import PhathomCore
import SwiftData
import SwiftUI

struct FocusTab: View {
    @Binding var selectedTab: Int

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FocusEntry.sortOrder, order: .forward)
    private var allEntries: [FocusEntry]

    @Query(
        filter: #Predicate<ContentItem> { !$0.isArchived },
        sort: \.createdAt,
        order: .reverse
    )
    private var activeItems: [ContentItem]

    @State private var navPath = NavigationPath()
    @State private var editMode: EditMode = .inactive
    @State private var focusOutcomeItem: ContentItem?
    @State private var focusTakeawayItem: ContentItem?
    @State private var focusRevisitItem: ContentItem?
    @State private var focusReferenceTargetItem: ContentItem?
    @State private var pendingFocusReferenceCategory = false
    @State private var focusReferenceCategoryHandled = false
    @State private var focusOutcomeSkipReleaseOnDismiss = false
    @State private var staleNudgeDismissedKeys = FocusStaleNudgeStorage.loadDismissedKeys()
    @State private var weeklyResetHiddenThisSession = false

    private var activeEntries: [FocusEntry] {
        allEntries.filter { entry in
            guard let item = entry.contentItem else { return false }
            return !item.isArchived
        }
    }

    private var staleNudgeEntry: FocusEntry? {
        FocusStalePresentation.nudgeCandidate(
            among: activeEntries,
            dismissedKeys: staleNudgeDismissedKeys
        )
    }

    private var openSlotCount: Int {
        max(FocusStackConstants.maxActiveEntries - activeEntries.count, 0)
    }

    private var showWeeklyResetPrompt: Bool {
        !weeklyResetHiddenThisSession
            && FocusWeeklyResetStorage.shouldShowPrompt(libraryItemCount: activeItems.count)
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                focusScrollChrome

                if showWeeklyResetPrompt {
                    weeklyResetBanner
                }

                if let nudgeEntry = staleNudgeEntry {
                    staleNudgeBanner(for: nudgeEntry)
                }

                if activeEntries.isEmpty {
                    emptyState
                } else {
                    ForEach(activeEntries) { entry in
                        focusRow(for: entry)
                    }
                    .onMove(perform: moveEntries)
                }
            }
            .environment(\.editMode, $editMode)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)
            .background(AppPalette.background)
            .navigationDestination(for: UUID.self) { id in
                focusDetailDestination(for: id)
            }
            .toolbar(.hidden, for: .navigationBar)
            .focusOutcomeFlow(
                outcomeItem: $focusOutcomeItem,
                takeawayItem: $focusTakeawayItem,
                revisitItem: $focusRevisitItem,
                referenceTargetItem: $focusReferenceTargetItem,
                pendingReferenceCategory: $pendingFocusReferenceCategory,
                referenceCategoryHandled: $focusReferenceCategoryHandled,
                skipReleaseOnOutcomeDismiss: $focusOutcomeSkipReleaseOnDismiss
            )
        }
    }

    private var focusScrollChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                FocusStackHeader(activeCount: activeEntries.count)
                Spacer(minLength: 0)
                if !activeEntries.isEmpty {
                    Button {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Text(editMode == .active ? "Done" : "Edit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.accent)
                            .phathomToolbarTextLabel()
                            .padding(.top, 20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .textCase(nil)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var weeklyResetBanner: some View {
        FocusWeeklyResetPrompt(
            openSlotCount: openSlotCount,
            activeCount: activeEntries.count,
            onGoToLibrary: {
                dismissWeeklyResetPrompt()
                selectedTab = 0
            },
            onDismiss: dismissWeeklyResetPrompt
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.bottom, 12)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func dismissWeeklyResetPrompt() {
        FocusWeeklyResetStorage.dismissForCurrentWeek()
        weeklyResetHiddenThisSession = true
    }

    private func staleNudgeBanner(for entry: FocusEntry) -> some View {
        let days = FocusStalePresentation.daysUntouched(lastTouchedAt: entry.lastTouchedAt)
        return FocusStaleNudgeBanner(
            message: FocusStalePresentation.nudgeMessage(daysUntouched: days),
            onKeep: { keepStaleNudge(for: entry) },
            onComplete: { completeStaleNudge(for: entry) },
            onRemove: { removeStaleNudge(for: entry) }
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.bottom, 12)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func keepStaleNudge(for entry: FocusEntry) {
        FocusStaleNudgeStorage.dismiss(entry: entry)
        staleNudgeDismissedKeys = FocusStaleNudgeStorage.loadDismissedKeys()
    }

    private func completeStaleNudge(for entry: FocusEntry) {
        guard let item = entry.contentItem else { return }
        focusOutcomeSkipReleaseOnDismiss = false
        focusOutcomeItem = item
    }

    private func removeStaleNudge(for entry: FocusEntry) {
        guard let item = entry.contentItem else { return }
        do {
            try FocusStackService.removeFromFocus(item: item, in: modelContext)
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
        } catch {
            return
        }
    }

    private var emptyState: some View {
        EditorialTwoTierEmptyState(
            title: "Nothing in focus yet",
            hint: "Add articles from Library or Detail when you're ready to commit."
        )
        .padding(.top, 16)
        .padding(.bottom, 24)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func focusRow(for entry: FocusEntry) -> some View {
        let isLast = entry.id == activeEntries.last?.id
        if let item = entry.contentItem {
            Button {
                guard editMode == .inactive else { return }
                navPath.append(item.id)
            } label: {
                FocusStackRow(
                    entry: entry,
                    showsBottomHairline: !isLast
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if editMode == .inactive {
                    Button("Complete") {
                        focusOutcomeSkipReleaseOnDismiss = false
                        focusOutcomeItem = item
                    }
                    .tint(AppPalette.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func focusDetailDestination(for id: UUID) -> some View {
        if let item = activeItems.first(where: { $0.id == id }) {
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

    private func moveEntries(from source: IndexSet, to destination: Int) {
        FocusStackService.reorder(
            entries: activeEntries,
            fromOffsets: source,
            toOffset: destination
        )
        try? modelContext.save()
    }
}

#Preview {
    FocusTab(selectedTab: .constant(2))
        .modelContainer(PreviewModel.makeContainer())
}
