import PhathomCore
import PhathomInference
import SwiftData
import SwiftUI

/// Sheet with two sections: exact tag matches and tag-adjacent suggestions (Stages 1 + 2, mirroring library Dive deeper).
/// On row tap, calls `onSelect` and dismisses; parent replaces navigation (`LibraryTab`) when a handler exists.
struct RelatedItemsSheet: View {
    let sourceItem: ContentItem
    let tappedTag: Tag
    let onSelect: (ContentItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ContentItem> { !$0.isArchived })
    private var allItems: [ContentItem]

    @State private var exactMatches: [ContentItem] = []
    /// Stage 1 adjacent (prefix + inverted index).
    @State private var stage1Related: [ContentItem] = []
    /// Llama-ranked adjacent; `nil` until Stage 2 finishes or skips.
    @State private var deepRankedRelated: [ContentItem]? = nil
    @State private var bucketsLoaded = false
    @State private var isRanking = false

    private var displayedRelated: [ContentItem] {
        deepRankedRelated ?? stage1Related
    }

    private var skeletonCount: Int {
        max(stage1Related.count, 3)
    }

    private var isEmptyState: Bool {
        bucketsLoaded && exactMatches.isEmpty && displayedRelated.isEmpty && !isRanking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                sheetBody
                    .fixedSize(horizontal: false, vertical: true)
                    .phathomSheetHeightMeasurable()
            }
            .background(AppPalette.background)
            .navigationTitle("Related to \"\(tappedTag.name)\"")
            .phathomInlineNavigationTitle()
            .toolbar {
                FlatToolbarTextItem(
                    title: "Done",
                    placement: PhathomToolbarPlacement.trailing,
                    foreground: AppPalette.accent,
                    action: { dismiss() }
                )
            }
        }
        .phathomSheetPresentation()
        .task { await runPipeline() }
    }

    @ViewBuilder
    private var sheetBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !bucketsLoaded {
                ProgressView()
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if isEmptyState {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(AppPalette.textTertiary)
                    Text("No related items")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                if !exactMatches.isEmpty {
                    sectionBlock(title: "With this tag") {
                        ForEach(exactMatches, id: \.id) { item in
                            relatedRowButton(item)
                        }
                    }
                }

                if !displayedRelated.isEmpty || isRanking {
                    sectionBlock(title: "Related by tags") {
                        if isRanking {
                            ForEach(0..<skeletonCount, id: \.self) { _ in
                                rankingPlaceholder
                            }
                        } else {
                            ForEach(displayedRelated, id: \.id) { item in
                                relatedRowButton(item)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.textPrimary)
                .padding(.bottom, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relatedRowButton(_ item: ContentItem) -> some View {
        Button {
            onSelect(item)
        } label: {
            ContentCardRow(item: item)
        }
        .buttonStyle(.plain)
    }

    /// Skeleton card matching `ContentCardRow.card` chrome.
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
        .accessibilityLabel("Loading related item")
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

    private func runPipeline() async {
        let buckets = RelatedItemsService.bucketsForTagTap(
            sourceItem: sourceItem,
            tappedTag: tappedTag,
            in: allItems
        )
        exactMatches = buckets.exactMatches
        stage1Related = buckets.adjacentCandidates
        bucketsLoaded = true

        let exactIDs = Set(exactMatches.map(\.id))

        guard ModelManager.hasReadableSelection else {
            deepRankedRelated = nil
            return
        }

        isRanking = true
        let ranked = await RelatedItemsService.rankedAdjacentAfterExpansion(
            sourceItem: sourceItem,
            tappedTag: tappedTag,
            in: allItems,
            exactMatchIDs: exactIDs,
            stage1Adjacent: stage1Related
        )
        deepRankedRelated = ranked.isEmpty ? nil : ranked
        isRanking = false
    }
}
