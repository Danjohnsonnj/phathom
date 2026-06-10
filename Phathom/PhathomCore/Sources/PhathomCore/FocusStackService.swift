import Foundation
import SwiftData

public enum FocusStackError: Error, Equatable, Sendable {
    case capFull
    case alreadyInFocus
    case notInFocus
    case archived
}

public enum FocusStackService {
    public static func activeEntries(in context: ModelContext) throws -> [FocusEntry] {
        let descriptor = FetchDescriptor<FocusEntry>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        let entries = try context.fetch(descriptor)
        return entries.filter { entry in
            guard let item = entry.contentItem else { return false }
            return !item.isArchived
        }
    }

    public static func isInFocus(_ item: ContentItem) -> Bool {
        item.focusEntry != nil
    }

    public static func countActive(in context: ModelContext) throws -> Int {
        try activeEntries(in: context).count
    }

    public static func canAddWithoutSwap(in context: ModelContext) throws -> Bool {
        try countActive(in: context) < FocusStackConstants.maxActiveEntries
    }

    public static func addToFocus(
        item: ContentItem,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !item.isArchived else { throw FocusStackError.archived }
        guard item.focusEntry == nil else { throw FocusStackError.alreadyInFocus }
        guard try canAddWithoutSwap(in: context) else { throw FocusStackError.capFull }

        let nextOrder = (try activeEntries(in: context).map(\.sortOrder).max() ?? -1) + 1
        let entry = FocusEntry(contentItem: item, sortOrder: nextOrder, now: now)
        context.insert(entry)
        item.focusEntry = entry
    }

    public static func removeFromFocus(
        item: ContentItem,
        in context: ModelContext,
        logRelease: Bool = false,
        completedAt: Date = .now
    ) throws {
        guard let entry = item.focusEntry else { throw FocusStackError.notInFocus }
        context.delete(entry)
        item.focusEntry = nil
        if logRelease {
            let outcome = FocusOutcome(contentItem: item, kind: .release, completedAt: completedAt)
            context.insert(outcome)
            item.focusOutcomes.append(outcome)
        }
    }

    public static func completeOutcome(
        item: ContentItem,
        kind: FocusOutcomeKind,
        in context: ModelContext,
        takeawayText: String? = nil,
        linkedHighlightID: UUID? = nil,
        scheduledResurfaceAt: Date? = nil,
        completedAt: Date = .now
    ) throws {
        guard item.focusEntry != nil else { throw FocusStackError.notInFocus }

        let outcome = FocusOutcome(
            contentItem: item,
            kind: kind,
            completedAt: completedAt,
            takeawayText: takeawayText,
            linkedHighlightID: linkedHighlightID,
            scheduledResurfaceAt: scheduledResurfaceAt
        )
        context.insert(outcome)
        item.focusOutcomes.append(outcome)

        if kind == .reference {
            item.readStatus = ReadStatus.filed.rawValue
        }

        if kind == .takeaway, let highlightID = linkedHighlightID, let text = takeawayText {
            if let highlight = item.highlights.first(where: { $0.id == highlightID }) {
                highlight.userNote = text
            }
        }

        try removeFromFocus(item: item, in: context, logRelease: false, completedAt: completedAt)
    }

    public static func touchEngagement(
        item: ContentItem,
        in context: ModelContext,
        now: Date = .now
    ) {
        guard item.focusEntry != nil else { return }
        item.focusEntry?.lastTouchedAt = now
    }

    public static func reorder(
        entries: [FocusEntry],
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        var ordered = entries.sorted { $0.sortOrder < $1.sortOrder }
        let moving = fromOffsets.sorted().map { ordered[$0] }
        var remaining = ordered.enumerated()
            .filter { !fromOffsets.contains($0.offset) }
            .map(\.element)
        let insertIndex = toOffset - fromOffsets.filter { $0 < toOffset }.count
        remaining.insert(contentsOf: moving, at: insertIndex)
        for (index, entry) in remaining.enumerated() {
            entry.sortOrder = index
        }
    }

    public static func dueForRevisit(
        _ item: ContentItem,
        in context: ModelContext,
        now: Date = .now
    ) -> Bool {
        guard item.focusEntry == nil else { return false }
        let revisitOutcomes = item.focusOutcomes.filter { $0.kind == .revisit }
        guard let latest = revisitOutcomes.max(by: { $0.completedAt < $1.completedAt }) else { return false }
        guard let due = latest.scheduledResurfaceAt else { return false }
        return due <= now
    }

    public static func releaseForSwap(
        entry: FocusEntry,
        in context: ModelContext,
        completedAt: Date = .now
    ) throws {
        guard let item = entry.contentItem else { return }
        context.delete(entry)
        item.focusEntry = nil
        let outcome = FocusOutcome(contentItem: item, kind: .release, completedAt: completedAt)
        context.insert(outcome)
        item.focusOutcomes.append(outcome)
    }

    /// Drops active Focus membership when an item is archived; no outcome log.
    public static func dropFocusEntryOnArchive(item: ContentItem, in context: ModelContext) {
        guard let entry = item.focusEntry else { return }
        context.delete(entry)
        item.focusEntry = nil
    }
}
