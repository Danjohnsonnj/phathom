import PhathomCore
import SwiftData
import SwiftUI

/// Sheet that lists up to 3 library items related to a tapped tag on the source item.
///
/// Stage 1 (sync) buckets candidates; Stage 2 (async Llama) re-ranks the adjacent bucket if needed.
/// On row tap, calls `onSelect` and dismisses; the parent (`DetailView`) is responsible for
/// replacing the navigation stack so the user lands on the chosen item's detail.
struct RelatedItemsSheet: View {
    let sourceItem: ContentItem
    let tappedTag: Tag
    let onSelect: (ContentItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ContentItem> { !$0.isArchived })
    private var allItems: [ContentItem]

    @State private var exactMatches: [ContentItem] = []
    /// Populated only after Stage 2 completes (or when a fast path skips inference). Stays empty
    /// while inference is in flight so unranked Bucket B is never rendered then re-ordered.
    @State private var rerankedAdjacent: [ContentItem] = []
    /// Number of placeholder cards to render below the exact matches while inference is in flight.
    @State private var pendingAdjacentCount = 0
    @State private var bucketsLoaded = false
    @State private var isRanking = false

    var body: some View {
        NavigationStack {
            content
                .background(AppPalette.background)
                .navigationTitle("Related to \"\(tappedTag.name)\"")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(AppPalette.accent)
                    }
                }
        }
        .task { await runPipeline() }
    }

    @ViewBuilder
    private var content: some View {
        if !bucketsLoaded {
            stateView { ProgressView().controlSize(.regular) }
        } else if exactMatches.isEmpty, rerankedAdjacent.isEmpty, !isRanking {
            stateView {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(AppPalette.textTertiary)
                    Text("No related items")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                }
            }
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        let displayed = RelatedItemsService.combinedTopResults(
            exactMatches: exactMatches,
            rerankedAdjacent: rerankedAdjacent
        )
        let placeholderSlots = isRanking
            ? max(0, min(RelatedItemsService.displayLimit - displayed.count, pendingAdjacentCount))
            : 0

        return ScrollView {
            VStack(spacing: 12) {
                ForEach(displayed, id: \.id) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        ContentCardRow(item: item)
                    }
                    .buttonStyle(.plain)
                }

                if placeholderSlots > 0 {
                    ForEach(0..<placeholderSlots, id: \.self) { _ in
                        rankingPlaceholder
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    /// Skeleton card matching `ContentCardRow.card` chrome so layout doesn't jump when ranked rows
    /// replace placeholders. No spinner or text — the skeleton itself is the loading affordance.
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

    private func stateView<V: View>(@ViewBuilder _ body: () -> V) -> some View {
        VStack {
            Spacer()
            body()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runPipeline() async {
        let buckets = RelatedItemsService.bucket(
            for: sourceItem,
            tappedTag: tappedTag,
            in: allItems
        )
        exactMatches = buckets.exactMatches

        if buckets.exactMatches.count >= RelatedItemsService.displayLimit
            || buckets.adjacentCandidates.isEmpty {
            rerankedAdjacent = []
            bucketsLoaded = true
            return
        }
        if !ModelManager.hasReadableSelection {
            rerankedAdjacent = buckets.adjacentCandidates
            bucketsLoaded = true
            return
        }

        let slotsRemaining = RelatedItemsService.displayLimit - buckets.exactMatches.count
        pendingAdjacentCount = min(slotsRemaining, buckets.adjacentCandidates.count)
        bucketsLoaded = true
        isRanking = true

        let ranked = await RelatedItemsService.rerankAdjacent(
            tappedTag: tappedTag,
            sourceItem: sourceItem,
            adjacentCandidates: buckets.adjacentCandidates
        )
        rerankedAdjacent = ranked
        pendingAdjacentCount = 0
        isRanking = false
    }
}
