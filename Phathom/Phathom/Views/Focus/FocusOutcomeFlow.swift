import PhathomCore
import SwiftData
import SwiftUI

extension ContentItem: @retroactive Identifiable {}

/// Shared outcome sheet orchestration for Detail, Focus tab, and Library long-press.
struct FocusOutcomeFlowModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Binding var outcomeItem: ContentItem?
    @Binding var takeawayItem: ContentItem?
    @Binding var revisitItem: ContentItem?
    @Binding var referenceTargetItem: ContentItem?
    @Binding var pendingReferenceCategory: Bool
    @Binding var referenceCategoryHandled: Bool
    @Binding var skipReleaseOnOutcomeDismiss: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: $outcomeItem, onDismiss: handleOutcomeSheetDismiss) { item in
                FocusOutcomeSheet(
                    item: item,
                    onPick: { kind in handleOutcomePick(kind, item: item) },
                    onCancel: { cancelOutcomeSheet(item: item) }
                )
            }
            .sheet(item: $takeawayItem) { item in
                FocusTakeawaySheet(
                    item: item,
                    onSave: { text, highlightID in
                        skipReleaseOnOutcomeDismiss = true
                        _ = FocusOutcomeCompletion.complete(
                            item: item,
                            kind: .takeaway,
                            modelContext: modelContext,
                            takeawayText: text,
                            linkedHighlightID: highlightID
                        )
                        takeawayItem = nil
                    },
                    onCancel: {
                        takeawayItem = nil
                        reopenOutcome(for: item)
                    }
                )
            }
            .sheet(item: $revisitItem) { item in
                FocusRevisitScheduleSheet(
                    item: item,
                    onSchedule: { date in
                        skipReleaseOnOutcomeDismiss = true
                        _ = FocusOutcomeCompletion.complete(
                            item: item,
                            kind: .revisit,
                            modelContext: modelContext,
                            scheduledResurfaceAt: date
                        )
                        revisitItem = nil
                    },
                    onCancel: {
                        revisitItem = nil
                        reopenOutcome(for: item)
                    }
                )
            }
            .sheet(isPresented: $pendingReferenceCategory, onDismiss: handleReferenceCategoryDismiss) {
                CategoryPicker { picked in
                    referenceCategoryHandled = true
                    guard let item = referenceTargetItem else { return }
                    finishReference(item: item, category: picked)
                }
            }
    }

    private func handleOutcomePick(_ kind: FocusOutcomeKind, item: ContentItem) {
        switch kind {
        case .reference:
            skipReleaseOnOutcomeDismiss = true
            outcomeItem = nil
            if item.category == nil {
                referenceTargetItem = item
                pendingReferenceCategory = true
            } else {
                _ = FocusOutcomeCompletion.completeReference(
                    item: item,
                    category: item.category,
                    modelContext: modelContext
                )
            }
        case .takeaway:
            skipReleaseOnOutcomeDismiss = true
            outcomeItem = nil
            takeawayItem = item
        case .revisit:
            skipReleaseOnOutcomeDismiss = true
            outcomeItem = nil
            revisitItem = item
        case .release:
            skipReleaseOnOutcomeDismiss = true
            _ = FocusOutcomeCompletion.complete(item: item, kind: .release, modelContext: modelContext)
            outcomeItem = nil
        }
    }

    private func cancelOutcomeSheet(item: ContentItem) {
        skipReleaseOnOutcomeDismiss = true
        outcomeItem = nil
    }

    private func handleOutcomeSheetDismiss() {
        skipReleaseOnOutcomeDismiss = false
        outcomeItem = nil
    }

    private func handleReferenceCategoryDismiss() {
        guard !referenceCategoryHandled else {
            referenceCategoryHandled = false
            return
        }
        guard let item = referenceTargetItem else { return }
        finishReference(item: item, category: nil)
    }

    private func finishReference(item: ContentItem, category: PhathomCore.Category?) {
        skipReleaseOnOutcomeDismiss = true
        _ = FocusOutcomeCompletion.completeReference(
            item: item,
            category: category,
            modelContext: modelContext
        )
        referenceTargetItem = nil
        pendingReferenceCategory = false
    }

    private func reopenOutcome(for item: ContentItem) {
        skipReleaseOnOutcomeDismiss = false
        outcomeItem = item
    }
}

extension View {
    func focusOutcomeFlow(
        outcomeItem: Binding<ContentItem?>,
        takeawayItem: Binding<ContentItem?>,
        revisitItem: Binding<ContentItem?>,
        referenceTargetItem: Binding<ContentItem?>,
        pendingReferenceCategory: Binding<Bool>,
        referenceCategoryHandled: Binding<Bool>,
        skipReleaseOnOutcomeDismiss: Binding<Bool>
    ) -> some View {
        modifier(
            FocusOutcomeFlowModifier(
                outcomeItem: outcomeItem,
                takeawayItem: takeawayItem,
                revisitItem: revisitItem,
                referenceTargetItem: referenceTargetItem,
                pendingReferenceCategory: pendingReferenceCategory,
                referenceCategoryHandled: referenceCategoryHandled,
                skipReleaseOnOutcomeDismiss: skipReleaseOnOutcomeDismiss
            )
        )
    }
}
