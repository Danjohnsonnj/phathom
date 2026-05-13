# Library bulk selection + triage

Self-contained spec for multi-select on the Library tab: bulk `ReadStatus` and bulk archive, plus batch undo on the root tab bar.

**Related code:** [`LibraryTab.swift`](../../Phathom/Phathom/Views/Library/LibraryTab.swift), [`MainTabView.swift`](../../Phathom/Phathom/Views/MainTabView.swift), [`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift), [`ContentItem+ReadStatus.swift`](../../Phathom/Phathom/Helpers/ContentItem+ReadStatus.swift), [`Notifications+Phathom.swift`](../../Phathom/Phathom/Helpers/Notifications+Phathom.swift).

---

## Purpose

User selects multiple library rows (including rows under **Related by tags**), then applies **Mark New**, **Mark Read**, **Mark Filed**, or **Archive** once for the whole set.

---

## UX

- **Select** (toolbar leading on Library): enters multi-select; **Done** exits and clears selection.
- **List** shows system selection affordance while active (`EditMode` + `List(selection:)`).
- **Bulk bar** (`safeAreaInset` bottom): visible only when Select mode is on **and** at least one row is selected. Shows count, **Mark as…** menu (three read statuses), **Archive** button.
- Tapping a row in Select mode toggles membership in the selection set; when Select mode is off, row opens **Detail** via `NavigationLink` as today.
- Leading/trailing **swipe actions** are hidden while Select mode is on (avoids conflicting gestures).

---

## SHALL (normative)

1. SHALL expose **Select** / **Done** on the Library navigation bar (leading).
2. SHALL use one `Set<UUID>` selection across **matching** and **Related by tags** rows in the same `List`.
3. SHALL offer bulk **Mark New**, **Mark Read**, **Mark Filed**, and **Archive** when selection is non-empty.
4. SHALL apply bulk read-status with **at most one** `ModelContext.save()` and **at most one** `LibraryContentChangeNotifier.postLibraryContentDidChange()` per user action.
5. SHALL apply bulk archive with **at most one** save and **at most one** library notifier after all `ArchiveRetention.archive` calls for that action.
6. SHALL post `phathomDidArchiveItem` with `userInfo` built via `PhathomArchiveNotification.userInfo(itemIDs:switchToLibrary:)` (see notification contract).
7. SHALL have **MainTabView** **Undo** restore **every** id in the last notification batch within the existing timeout.
8. SHALL read archive ids with `PhathomArchiveNotification.itemIDs(from:)` (**`itemIDs` first**, then legacy **`itemID`**).
9. SHALL clear selection after a successful bulk Mark or Archive; **remain** in Select mode until **Done**.
10. SHALL clear selection and exit Select mode on **Done**.

---

## Notification contract + audit

| Key | Type | Writers | Readers | Notes |
|-----|------|-----------|---------|-------|
| `itemIDs` | `[String]` (UUID strings) | `LibraryTab` (swipe + bulk), `DetailView` archive | `PhathomArchiveNotification.itemIDs(from:)` | Primary batch payload; plist-safe. |
| `itemID` | `UUID` | Same writers when count == 1 (optional mirror) | Parser fallback if `itemIDs` absent | Legacy single-id posts. |
| `switchToLibrary` | `Bool` | unchanged | `MainTabView` | Default `true`. |

**Posters (grep `phathomDidArchiveItem`):**

- [`LibraryTab.swift`](../../Phathom/Phathom/Views/Library/LibraryTab.swift) — row swipe + bulk archive.
- [`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift) — archive from detail.

**Receivers:**

- [`MainTabView.swift`](../../Phathom/Phathom/Views/MainTabView.swift) — undo snackbar + tab switch.
- [`SettingsTab.swift`](../../Phathom/Phathom/Views/Settings/SettingsTab.swift) — refresh archived count (unchanged).

**Rapid consecutive archives:** each notification **replaces** the undo batch (same semantics as single-item before batching). Documented here so future work does not “stack” undo batches.

---

## Ambiguity defaults (Step 2)

| Situation | Behavior |
|-----------|----------|
| After bulk Mark or Archive | Clear selection; stay in Select mode. |
| Done | Exit Select mode; clear selection. |
| Bulk archive confirm | No system alert (parity with swipe). |
| Selected id missing from live `items` | Skip that id; no crash. |
| Accessibility | `Select` / `Done` labels; bulk bar value describes count and actions. |
| Dive deeper row | Remains enabled in Select mode unless QA finds conflict (then disable in follow-up). |

---

## Out of scope

- Bulk restore / unarchive from Library.
- Bulk tag edit, delete, export.
- Merging archive into `ReadStatus` UI control.
- Pipeline / `SharedLlamaInference` changes.

---

## Risks

- `NavigationLink` vs selection: mitigated by plain row when `EditMode.active`.
- Duplicate `ContentItem` in matching + adjacent: possible edge case for `ForEach` ids; smoke test; dedupe in `LibrarySearchService` if needed later.

---

## Acceptance criteria (merge gate)

Copy from implementation plan / verify in PR:

- [ ] Handoff matches shipped behavior (this doc + code).
- [ ] `docs/decisions.md` row for batch archive notification + undo.
- [ ] Select / Done + selection clearing per defaults table.
- [ ] `List` selection + `.tag(\.id)` on selectable rows (both sections).
- [ ] Bulk read: one save + one library notifier per action.
- [ ] Bulk archive: one save + one notifier; `itemIDs` lists every archived id.
- [ ] MainTabView: batch undo; snackbar singular vs plural.
- [ ] Legacy `itemID`-only post still undoes one item.
- [ ] Single swipe + Detail archive + Settings count refresh.
- [ ] Phase 1 regression: filters, search, detail navigation when not selecting; swipes when not selecting.
- [ ] `bash scripts/build-phathom.sh all` clean (or PR notes SDK gap).
- [ ] `LibraryTab` Preview compiles.
- [ ] Manual: no duplicate-id SwiftUI crash on tag-related library layout.

---

## Testing

- **Unit:** `PhathomTests` covers `ContentItem.applyReadStatus(_:to:modelContext:)` batch path when feasible (`@testable import Phathom`).
- **Manual:** AC checklist above.

---

## PR description template (completion)

1. Paste **Acceptance criteria** checkboxes; mark met / waived + reason.
2. Build: `bash scripts/build-phathom.sh all`.
3. List Step 1–2 workarounds from handoff decision framework (e.g. conditional row if NavigationLink fought selection).
4. Note Phase 1 regression spot-check (filters, search, detail, swipes).
