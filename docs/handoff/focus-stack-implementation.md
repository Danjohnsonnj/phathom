# Focus Stack — Technical Implementation Plan

> **Status:** Phase 4 **approved** (forks locked **2026-06-09**; plan review edits applied). Ready for Swift **Phase 5** slice A0.  
> **Authority:** Locked UX in [`focus-stack.md`](focus-stack.md) · [`docs/decisions.md`](../decisions.md) **2026-06-09** rows · canonical mocks [`focus-stack-ad-*.html`](../archive/design-mocks/). **Code wins** on conflict once shipped.

**Related:** [`focus-stack-delivery.md`](focus-stack-delivery.md) · [`docs/design-tokens.md`](../design-tokens.md) · [`CONTEXT.md`](../../CONTEXT.md)

---

## 1. Scope summary

### Completion gates (locked)

| Gate | Meaning |
|------|---------|
| **Phase A ships** | First user-visible Focus Stack — core loop works (tab, Detail, outcomes, cap, scope icon). Safe to merge and QA incrementally. |
| **Phase B ships** | **Focus v1 complete** — stale treatment, revisit clock, weekly ritual, and scheduling polish. Not optional polish; **required** before declaring Focus done. Execute **after** Phase A slices satisfy each item's `Depends on`. |
| **Phase A+ (post-acceptance)** | Library long-press Add/Remove — **only after** user accepts Detail Focus implementation (A4–A5 QA). |

**Chosen path (fork lock 2026-06-09):**

- **Revisit clock** → **B3** (not Phase A). A5 stores `scheduledResurfaceAt`; B3 surfaces Library **clock** when due. Revisit outcome is usable in A; resurface **signal** completes in B.
- **Library long-press** → **deferred to Phase A+** until Detail add/remove is accepted in manual QA.

| Phase | Ships | Out of this phase |
|-------|-------|-------------------|
| **A — MVP** | `FocusEntry` + `FocusOutcome` · cap **7** + swap (Release-only) · **Focus tab** (replaces Chat) · Detail Focus toggle + **Done in Focus** · outcome sheet (Reference · Takeaway · Revisit · Release) · Focus list reorder + swipe Complete · Library trailing **scope** icon only · `lastTouchedAt` writes · backup **v4** | Stale tint + nudge · Library **clock** · weekly ritual · long-press context menu |
| **B — Complete v1** | **Required for Focus complete:** B1–B5 (stale tint · nudge · **clock** · revisit UX polish · weekly reset) | B6 Notebook provenance (stretch) |
| **A+ — Library entry** | Long-press Add/Remove Focus (after Detail acceptance) | — |
| **C — Connect** | Thread entity · Connect outcome · thread-scoped assist | Separate gate after Focus v1 complete |

**Hard rules (do not re-litigate):** Focus tab replaces Chat · cap 7 force-swap · Detail Category-parity Focus toggle · Library icon-only trailing signals · **no** leading Focus swipe · stale clock scoped to **`FocusEntry.lastTouchedAt`** since current membership · Chat/RAG frozen.

### Delivery playbook mapping

[`focus-stack-delivery.md`](focus-stack-delivery.md) phase numbers ↔ this plan:

| Delivery phase | This plan | Exit |
|----------------|-----------|------|
| **5 — Impl A** | Slices **A0–A9** | Phase A manual QA (§10) |
| **6 — Impl B** | Slices **B1–B5** | Focus v1 complete QA (§10) |
| *(post-acceptance)* | **A+1** | Optional; not a delivery phase gate |
| **7 — Impl C** | Phase **C** | Connect / Thread — separate gate |

---

## 2. SwiftData models

### 2.1 New types (PhathomCore)

Add to [`Phathom/PhathomCore/Sources/PhathomCore/Enums.swift`](../../Phathom/PhathomCore/Sources/PhathomCore/Enums.swift):

```swift
public enum FocusOutcomeKind: String, Codable, CaseIterable, Sendable {
    case reference
    case takeaway
    case revisit
    case release
}
```

**Constants** (PhathomCore, e.g. `FocusStackConstants.swift`):

| Constant | Value |
|----------|-------|
| `maxActiveEntries` | **7** (fixed v1) |
| `staleUntouchedDays` | **7** (Phase B UI only; field writes in A) |

#### `FocusEntry` — active membership (max 7 rows globally)

```swift
@Model
public final class FocusEntry {
    @Attribute(.unique) public var id: UUID
    public var addedAt: Date
    public var sortOrder: Int
    public var lastTouchedAt: Date

    @Relationship(inverse: \ContentItem.focusEntry)
    public var contentItem: ContentItem?

    public init(contentItem: ContentItem, sortOrder: Int, now: Date = .now) {
        self.id = UUID()
        self.contentItem = contentItem
        self.addedAt = now
        self.sortOrder = sortOrder
        self.lastTouchedAt = now  // init = addedAt
    }
}
```

#### `FocusOutcome` — append-only closure log

```swift
@Model
public final class FocusOutcome {
    @Attribute(.unique) public var id: UUID
    public var completedAt: Date
    public var outcomeKind: String  // FocusOutcomeKind.rawValue

    public var takeawayText: String?
    public var linkedHighlightID: UUID?
    public var scheduledResurfaceAt: Date?

    @Relationship(inverse: \ContentItem.focusOutcomes)
    public var contentItem: ContentItem?

    public init(
        contentItem: ContentItem,
        kind: FocusOutcomeKind,
        completedAt: Date = .now,
        takeawayText: String? = nil,
        linkedHighlightID: UUID? = nil,
        scheduledResurfaceAt: Date? = nil
    ) { … }
}
```

#### `ContentItem` additions

```swift
@Relationship(deleteRule: .cascade) public var focusEntry: FocusEntry?
@Relationship(deleteRule: .cascade) public var focusOutcomes: [FocusOutcome] = []
```

**Invariants enforced in service layer (not DB unique beyond 1:1 `focusEntry`):**

- At most **one** `FocusEntry` per `ContentItem` (via optional 1:1 relationship).
- At most **7** `FocusEntry` rows total among **non-archived** items (count query before insert).
- **`focusEntry != nil` ⟺ item is in Focus** — delete row on any leave path.

**Leave Focus (delete `FocusEntry`):** toggle off · any outcome completion · swap Release · archive item · permanent delete item.

**Re-add:** new `FocusEntry` → **`lastTouchedAt = addedAt`** (clock resets).

### 2.2 Derived / query helpers (no stored fields)

| Computed | Rule |
|----------|------|
| `daysInFocus` | Whole calendar days from `addedAt` to now — **display only** |
| `daysUntouched` | Whole calendar days from `lastTouchedAt` to now — via shared helper (e.g. `FocusCalendar.wholeDays(from:to:)` in PhathomCore; `Calendar` start-of-day semantics, match app date formatting elsewhere) |
| `staleIntensity` (Phase B) | `daysUntouched ≥ 7` → `min(Double(daysUntouched - 6) / 7.0, 1.0)` else `0` |
| **Due for revisit** | Among `FocusOutcome` rows where `kind == .revisit`, take **latest by `completedAt` desc`**; due when item **not** in Focus and that row's `scheduledResurfaceAt ≤ now` |
| **Library trailing icon** | In Focus → **scope** (paprika, 22pt); else if due for revisit → **clock** (secondary, 22pt); **never both** |

**`lastTouchedAt` bump (Phase A writes, Phase B reads):**

1. Detail **`onAppear`** for item with active `focusEntry`.
2. New **`Highlight`** inserted on item while in Focus — hook **`DetailView.createHighlightFromWebView`** ([`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift)); re-grep for other insert sites if added later.

Pre–add-to-Focus Detail opens / highlights **do not** backfill.

### 2.3 Schema version bump

| Item | Choice |
|------|--------|
| New version | **`PhathomSchemaV5`** — adds `FocusEntry`, `FocusOutcome`; `PhathomModelContainer.currentSchema` → V5 |
| Migration plan | **None** — lightweight additive entities (same pattern as `Category` / `Highlight`; see [`StoreMigrationSmokeTests`](../../Phathom/PhathomCore/Tests/PhathomCoreTests/StoreMigrationSmokeTests.swift)) |
| Legacy V4 store | Opens on V5 schema; empty Focus tables; no backfill |
| Smoke test | Add **`testV4StoreMigratesToV5AndAcceptsFocusEntry`** — seed **V4** on-disk store, open with **V5** schema (distinct from existing V1→current test in [`StoreMigrationSmokeTests`](../../Phathom/PhathomCore/Tests/PhathomCoreTests/StoreMigrationSmokeTests.swift)) |
| Share extension | **PhathomShare** uses same `PhathomModelContainer` — V5 additive schema; no Focus UI in extension; verify Share target builds in **A0** |
| Chat models | **`ChatThread` / `ChatMessage` unchanged** — schema stays registered; no tab surface |

**Escalation (not in MVP):** If lightweight migration fails in the field → document `VersionedSchema` migration plan; not expected for additive-only change.

---

## 3. Service layer — `FocusStackService`

**Location:** `Phathom/PhathomCore/Sources/PhathomCore/FocusStackService.swift` (testable from PhathomCoreTests; UI wraps via thin `@MainActor` facade if needed).

| API | Behavior |
|-----|----------|
| `activeEntries(context)` | Fetch all `FocusEntry`, sort `sortOrder` asc; filter `!contentItem.isArchived` |
| `isInFocus(_ item)` | `item.focusEntry != nil` |
| `countActive(context)` | `activeEntries.count` |
| `canAddWithoutSwap(context)` | `count < 7` |
| `addToFocus(item, context)` | Guard not archived, not already in Focus; if count == 7 → **throw `.capFull`**; else insert entry with `sortOrder = max+1` |
| `removeFromFocus(item, context, logRelease: Bool)` | Delete `focusEntry`; optional `FocusOutcome` Release row only when `logRelease` (swap path uses `true`) |
| `completeOutcome(item, kind, …)` | Append `FocusOutcome`; delete `focusEntry`; side effects per kind (§4) |
| `touchEngagement(item, context)` | If `focusEntry` exists → `lastTouchedAt = now` |
| `reorder(entries, fromOffsets, toOffset)` | Rewrite `sortOrder` contiguous |
| `dueForRevisit(item, context)` | Latest revisit `FocusOutcome` by **`completedAt` desc**; due when `scheduledResurfaceAt ≤ now` and item not in Focus |
| `releaseForSwap(entry, context)` | Delete entry + append Release outcome (swap-only semantics) |

**Archive hook (slice A1):** Extend [`ArchiveRetention.archive`](../../Phathom/Phathom/Services/ArchiveRetention.swift) to delete `focusEntry` on archive — no orphan memberships. **`ArchiveRetention.restore`** does **not** re-add to Focus; user must toggle again from Detail.

**Cap enforcement:** All add paths (`Detail` toggle, context menu, post-swap) go through service; UI never inserts `FocusEntry` directly.

---

## 4. Outcome side effects (Phase A)

| Outcome | Focus | `FocusOutcome` | `ReadStatus` | Other |
|---------|-------|----------------|--------------|-------|
| **Reference** | Remove | Log | → **`filed`** (user may override before confirm — default only) | **Uncategorized:** `CategoryPicker` → `applyFiled(category:)` · **Already categorized:** `applyFiled(category: item.category)` — no sheet |
| **Takeaway** | Remove | Log + `takeawayText` / `linkedHighlightID` | Unchanged default | Pin path: one-time copy to `Highlight.userNote` |
| **Revisit** | Remove | Log + `scheduledResurfaceAt` | Unchanged | **A5:** presets **1w / 1m / custom** (minimal date picker) · **B4:** UX polish only |
| **Release** | Remove | Log | Unchanged | None |
| **Swap Release** | Remove swapped | Log Release on **removed** item only | Unchanged | No outcome sheet |

**Takeaway pin sync:** On complete with `linkedHighlightID`, set `highlight.userNote` from takeaway text **once**; later highlight edits do not rewrite outcome log.

**Reference + Category:** Reuse existing [`CategoryPicker`](../../Phathom/Phathom/Views/Library/CategoryPicker.swift) sheet pattern from Detail filing (`pendingFileCategorySheet` flow).

---

## 5. UI surfaces

### 5.1 Tab bar — Chat → Focus

**File:** [`MainTabView.swift`](../../Phathom/Phathom/Views/MainTabView.swift)

| Before | After |
|--------|-------|
| `ChatTab()` tag 2 · `bubble.left.and.bubble.right` | `FocusTab()` tag 2 · **`scope`** (mock: target/scope, paprika when selected) |

- Remove Chat tab from `TabView`; **delete** [`ChatTab.swift`](../../Phathom/Phathom/Views/Chat/ChatTab.swift) from target in slice **A2** (see §12); **`ChatThread` / `ChatMessage`** models stay in schema.
- Tab order unchanged: Library · Notebook · Focus · Add New.
- Deep links / notifications: no change (Library tab 0).

### 5.2 Focus tab (new)

**Files:**

| File | Role |
|------|------|
| `Phathom/Phathom/Views/Focus/FocusTab.swift` | Root: `NavigationStack` + unified scroll (Notebook/Library parity) |
| `Phathom/Phathom/Views/Focus/FocusStackHeader.swift` | `EditorialScreenTitle("Focus")` + **`N of 7 · M open`** subline |
| `Phathom/Phathom/Views/Focus/FocusStackRow.swift` | Title · host/kind · days-in-focus · `ReadStatus` secondary · summary snippet · highlight count |
| `Phathom/Phathom/Views/Focus/FocusTabViewModel.swift` | Optional: `@Query` + reorder state |

**Behavior (Phase A):**

- `@Query` sorted `FocusEntry.sortOrder` · filter archived items out in view model.
- Tap row → [`LibraryDetailRoute`](../../Phathom/Phathom/Views/Library/LibraryDetailRoute.swift) → `DetailView` on Focus `NavigationStack` (media prewarm parity with Library/Notebook); back returns to Focus.
- **Reorder:** `List` + `.onMove` (edit mode) or drag handles — match iOS list reorder conventions.
- **Swipe trailing Complete** → present `FocusOutcomeSheet` (same as Done in Focus).
- **Empty state:** editorial two-tier when 0 entries (mock copy).
- **No ghost rows** — header carries open-slot copy only.

**Phase B additions (same files):** `staleIntensity` leading bar + row wash · **Untouched N days** meta · stale nudge banner/sheet.

**Tokens:** `AppSpacing.screenHorizontal` (22pt) · `tabBarScrollInset` · `AppPalette.accent` · hairline row dividers like [`GalleryListRow`](../../Phathom/Phathom/Views/Shared/GalleryListRow.swift).

### 5.3 Detail — Focus row + Done in Focus

**File:** [`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift)

**Section order (insert):**

```
readingStatusSection
focusSection          // NEW — after Read status
categorySection
```

**Focus row (Category parity):**

| Element | Spec |
|---------|------|
| Layout | Hairline section · `HStack` · label **Focus** 17pt semibold left · **`Toggle`** right |
| Toggle on | Paprika tint · show **Done in Focus** in `actionButtons` **above** Summarize again |
| Toggle off | Remove membership (no outcome) — F-04 mistake path |
| Toggle on at cap | Present **`FocusSwapSheet`**; cancel → toggle stays off; confirm Release → add |

**Done in Focus:** `HairlineCapsuleButton` → `FocusOutcomeSheet`.

**Focus closure indicator (slice A10):** When item is **not** in Focus and has ≥1 `FocusOutcome`, show a read-only line **below the Focus row** (same hairline section band or immediate subline). Copy from **latest** outcome by `completedAt` desc — e.g. `Reference · completed Apr 3` (outcome label + relative or short date). **15pt secondary**; no navigation action v1. **Hidden** while `focusEntry != nil`. **No** processed-focus gallery tab in v1 — this row is the sole Detail affordance for past closure. Log remains append-only; re-add to Focus does not erase history.

**Engagement touch:** `.onAppear` → `FocusStackService.touchEngagement` when in Focus.

Mock: [`focus-stack-ad-detail-a.html`](../archive/design-mocks/focus-stack-ad-detail-a.html).

### 5.4 Sheets

**Shared shell:** [`phathomSheetPresentation()`](../../Phathom/Phathom/Helpers/PhathomSheetPresentation.swift) on `NavigationStack` (outcome + swap families).

| Sheet | File | Phase |
|-------|------|-------|
| **Outcome picker** | `FocusOutcomeSheet.swift` | A |
| **Takeaway sub-flow** | `FocusTakeawaySheet.swift` (text + optional highlight pin) | A |
| **Revisit schedule** | `FocusRevisitScheduleSheet.swift` or inline step in outcome sheet | **A5** presets · **B4** polish |
| **Cap swap** | `FocusSwapSheet.swift` | A |
| **Stale nudge** | `FocusStaleNudgeSheet.swift` | B |

**Outcome sheet:** Four tappable rows (Reference · Takeaway · Revisit · Release) — not guilt modal. **Cancel** toolbar + swipe-dismiss = **abort** (item **stays in Focus**; no `FocusOutcome` written). **Release** only via explicit **Release** row (or stale nudge / swap paths per their sheets). Sub-flow Cancel (Takeaway / Revisit) returns to outcome picker without completing.

Mock: [`focus-stack-ad-sheets-a.html`](../archive/design-mocks/focus-stack-ad-sheets-a.html).

### 5.5 Library — trailing icons only

**Files:**

| File | Change |
|------|--------|
| [`GalleryListRow.swift`](../../Phathom/Phathom/Views/Shared/GalleryListRow.swift) | Trailing **22×22** icon slot — **A7:** `scope` paprika when in Focus; **B3:** `clock` secondary when revisit due |
| [`LibraryTab.swift`](../../Phathom/Phathom/Views/Library/LibraryTab.swift) | **No** context menu in A or B; long-press → **Phase A+** after Detail acceptance; **do not** add leading Focus swipe |

**Leading swipe:** unchanged — [`readStatusSwipeButtons`](../../Phathom/Phathom/Views/Library/LibraryTab.swift) owns leading edge.

**Icon precedence:** `inFocus` wins over `dueForRevisit` (mutually exclusive by product rule).

Mock: [`focus-stack-ad-library-chrome-a.html`](../archive/design-mocks/focus-stack-ad-library-chrome-a.html).

---

## 6. Phase A — implementation slices

Execute in order; each slice = build + targeted tests green before next.

| Slice | Deliverable | Key files |
|:-----:|-------------|-----------|
| **A0** | Schema V5 + models + enums + migration smoke | `PhathomSchema.swift`, `FocusEntry.swift`, `FocusOutcome.swift`, `ContentItem.swift`, `PhathomModelContainer.swift`, `StoreMigrationSmokeTests.swift` — **also:** add new files to Phathom + PhathomCore (+ test) Xcode targets; Share extension builds on V5 |
| **A1** | `FocusStackService` + unit tests + **archive `focusEntry` cleanup** | `FocusStackService.swift`, `FocusCalendar` helper, `ArchiveRetention.swift`, `Phathom/PhathomCore/Tests/PhathomCoreTests/FocusStackServiceTests.swift` |
| **A2** | Tab swap + Focus tab shell (empty list OK) | `MainTabView.swift`, `FocusTab.swift`, `FocusStackHeader.swift` |
| **A3** | Focus list rows + `@Query` + reorder + nav via `LibraryDetailRoute` | `FocusStackRow.swift`, `FocusTab.swift` |
| **A4** | Detail Focus toggle + remove-without-outcome | `DetailView.swift` — **interim until A6:** at cap **7/7**, block toggle-on (no-op / disabled); full swap path lands in **A6** |
| **A5** | Outcome sheet + complete flows (Reference/Takeaway/Revisit/Release) | `FocusOutcomeSheet.swift`, `FocusTakeawaySheet.swift`, `FocusRevisitScheduleSheet.swift`, `DetailView.swift`, `FocusTab.swift` |
| **A6** | Cap swap sheet + toggle-at-cap path | `FocusSwapSheet.swift`, `DetailView.swift`, optional Focus tab add |
| **A7** | Library **scope** icon only (in Focus) | `GalleryListRow.swift` |
| **A8** | Engagement touches (Detail appear + `createHighlightFromWebView`) | `DetailView.swift` |
| **A9** | Backup export/import v4 + `decisions.md` append | `LibraryBackupService.swift`, tests, `docs/decisions.md` |
| **A10** | Detail **focus closure indicator** (last outcome when not in Focus) | `DetailView.swift` (or `FocusClosureIndicator.swift`) — **Depends on A5** |

**ChatTab removal:** Slice **A2**.

**Revisit clock icon (locked):** **B3 only** — store `scheduledResurfaceAt` in **A5**; clock UI ships with Phase B completion gate.

**Phase B execution order:** B1 → B2 (after A8) · B3 + B4 (after A5) · B5 (after A3) — slices may interleave once dependencies met; all **B1–B5 required** before Focus v1 sign-off.

---

## 7. Phase B — required for Focus v1 complete

| ID | Feature | Files (planned) | Depends on | Required |
|----|---------|-----------------|------------|:--------:|
| B1 | Progressive stale row tint + **Untouched N days** meta | `FocusStackRow.swift`, `FocusStalePresentation.swift` | A8 `lastTouchedAt` | ✓ |
| B2 | Stale nudge sheet/banner (Keep / Complete / Remove) | `FocusStaleNudgeSheet.swift`, `FocusTab.swift` | B1 | ✓ |
| B3 | Library **clock** icon when revisit due | `GalleryListRow.swift`, `FocusStackService.dueForRevisit` | A5 Revisit outcomes | ✓ |
| B4 | Revisit scheduling **UX polish** (custom date picker refinement — presets ship in A5) | `FocusRevisitScheduleSheet.swift` | A5 | ✓ |
| B5 | Weekly in-app Focus reset prompt | `FocusWeeklyResetPrompt.swift`, `UserDefaults` dismiss flag | A3 list | ✓ |
| B6 | Notebook takeaway provenance | Notebook views | A5 Takeaway | stretch |

**Formula (locked):** `staleIntensity = min((daysUntouched − 6) / 7, 1)` · leading bar opacity = intensity · row wash ≈ `intensity × 0.22`.

---

## 7b. Phase A+ — Library long-press (post Detail acceptance)

**Gate:** User manual QA sign-off on **A4 Detail Focus toggle** + **A5 outcome flows** before starting A+.

| Slice | Deliverable | Key files |
|:-----:|-------------|-----------|
| **A+1** | Library context menu Add to Focus / Remove from Focus | `LibraryTab.swift`, reuse `FocusStackService` + swap sheet |

Same cap/swap rules as Detail. **Not** in Phase A or B completion criteria.

---

## 8. File inventory (full)

### New — PhathomCore

- `FocusEntry.swift`
- `FocusOutcome.swift`
- `FocusStackConstants.swift`
- `FocusStackService.swift`
- `FocusStalePresentation.swift` (Phase B — optional stub in A)
- `Phathom/PhathomCore/Tests/PhathomCoreTests/FocusStackServiceTests.swift`
- `FocusCalendar.swift` (or equivalent whole-day helper)

### New — Phathom app

- `Views/Focus/FocusTab.swift`
- `Views/Focus/FocusStackHeader.swift`
- `Views/Focus/FocusStackRow.swift`
- `Views/Focus/FocusOutcomeSheet.swift`
- `Views/Focus/FocusTakeawaySheet.swift`
- `Views/Focus/FocusRevisitScheduleSheet.swift`
- `Views/Focus/FocusSwapSheet.swift`
- `Views/Focus/FocusStaleNudgeSheet.swift` (Phase B)

### Modified

- `PhathomSchema.swift` — V5
- `PhathomModelContainer.swift` — V5 schema
- `ContentItem.swift` — relationships
- `Enums.swift` — `FocusOutcomeKind`
- `MainTabView.swift` — Focus tab
- `DetailView.swift` — Focus row, Done, sheets, closure indicator (A10), touch
- `GalleryListRow.swift` — trailing icons
- `LibraryTab.swift` — context menu (**Phase A+** only)
- `ArchiveRetention.swift` — drop `focusEntry` on archive
- `LibraryBackupService.swift` — v4 envelope fields
- Highlight create path — touch hook

### Removed / unreferenced

- `Views/Chat/ChatTab.swift` — remove from target when Focus ships (keep chat **models**)

---

## 9. Backup & restore (format v4)

Extend [`LibraryBackupService`](../../Phathom/PhathomCore/Sources/PhathomCore/LibraryBackupService.swift):

| Field | Notes |
|-------|-------|
| `formatVersion` | **4** |
| Per item: `focusOutcomes: [FocusOutcomeRecord]` | Append-only history |
| Global or per-item: active membership | Export `focusEntry` snapshot (`addedAt`, `sortOrder`, `lastTouchedAt`) keyed by `contentItemID` |

**Import:** Merge/Repair policies mirror v3; recreate `FocusEntry`/`FocusOutcome` rows; if import would exceed **7** active Focus entries → **reject** with copyable diagnostic (§12; no silent truncate).

**Tests:** `LibraryBackupServiceTests` — round-trip Focus rows.

---

## 10. Test plan

### Unit — PhathomCoreTests

| Test | Assert |
|------|--------|
| `addToFocus` under cap | Creates entry; `lastTouchedAt == addedAt` |
| `addToFocus` at cap | Throws / returns `.capFull` |
| `removeFromFocus` | Entry deleted; no outcome unless Release logged |
| `completeOutcome` each kind | Entry deleted; log row fields set |
| `releaseForSwap` | Release outcome on swapped item only |
| Re-add after remove | New entry; fresh `addedAt` / `lastTouchedAt` |
| `touchEngagement` | Updates `lastTouchedAt`; no-op when not in Focus |
| `dueForRevisit` | True when latest revisit past due and not in Focus |
| Reorder | Stable contiguous `sortOrder` |
| Archive item | `focusEntry` cleared |
| Migration V4→V5 | Existing `ContentItem` count preserved |

### Unit — PhathomTests (app)

| Test | Assert |
|------|--------|
| `FocusStalePresentation` (B) | Intensity 0 below 7d; caps at 1.0 |
| Backup v4 round-trip | Focus entries/outcomes survive export/import |

### Manual QA — Phase A sign-off (MVP merge)

1. **Tab:** Focus tab visible; Chat tab gone; icon `scope`; paprika when selected.
2. **Detail toggle:** Off → on adds; on → off removes without sheet; at **7/7** on → swap sheet → Release one → new item added; cancel aborts add.
3. **Done in Focus:** Outcome sheet from Detail + Focus swipe Complete; **Cancel** / swipe-dismiss → item **stays in Focus**; **Release** row removes + logs; Reference uncategorized → Category sheet then **filed**; categorized Reference → **filed** with existing category, no sheet.
4. **Takeaway:** Text-only logs; pin path sets highlight note.
5. **Revisit:** Pick 1w → leaves Focus; `scheduledResurfaceAt` persisted (**no clock yet** — expected until B3).
6. **Focus tab:** Header `N of 7`; reorder persists relaunch; days-in-focus visible; tap → Detail → back to Focus.
7. **Library:** In Focus → trailing **scope** only (no clock until B3); leading swipe still ReadStatus only; archived in-Focus item disappears from Focus list.
8. **Regression:** Notebook, Add New, Settings, ReadStatus swipe, category filing unchanged.
9. **Closure indicator (A10):** After Reference/Takeaway/Revisit/Release, Detail shows last outcome line when not in Focus; hidden while in Focus; no processed-focus history tab.

**Detail acceptance gate:** Items 2–3 pass → user may authorize **Phase A+** long-press work.

### Manual QA — Phase B sign-off (Focus v1 complete)

1. **Stale tint:** Row wash + **Untouched N days** at ≥7d since `lastTouchedAt`; intensity caps at 13+ days.
2. **Stale nudge:** Keep / Complete / Remove at threshold.
3. **Revisit clock:** Due item shows trailing **clock** (secondary, 22pt); mutually exclusive with scope; re-add manual.
4. **Weekly reset:** Prompt dismissible; does not block capture.
5. **Revisit scheduling:** Custom date UX polished (B4).

### Verify ladder (Phase 5+)

Per [`.cursor/rules/simulator-verify.mdc`](../../.cursor/rules/simulator-verify.mdc): simulator build · warning grep · `PhathomTests` green.

---

## 11. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Lightweight migration fails on device | Pre-release smoke from V4 fixture; escalation path documented §2.3 |
| Cap race (two adds) | Single `modelContext.save()` per operation; UI disables toggle while swap sheet open |
| Orphan `FocusEntry` on archive | Central archive hook |
| `dueForRevisit` query cost | Fetch latest revisit outcome per visible row — cache in view model; predicate on `FocusOutcome` indexed by `contentItem` |
| Takeaway / note divergence | Outcome log is truth; one-time denormalize only |
| Chat code rot | Delete `ChatTab` view; retain schema for future thread assist |

---

## 12. Locked decisions (2026-06-09)

| Topic | Decision |
|-------|----------|
| Focus v1 complete | Phase **A** + Phase **B** (B1–B5 required; B6 stretch) |
| Revisit clock icon | **B3** — data in A5, UI in B |
| Library long-press | **Phase A+** — after Detail (A4–A5) user acceptance |
| Outcome sheet **Cancel** / swipe-dismiss | **Abort** — stay in Focus; no outcome log |
| Outcome sheet **Release** | Explicit row only (not Cancel) |
| Focus closure on Detail (v1) | **Last outcome** subline when not in Focus (A10); **no** processed-focus gallery |
| Backup import >7 Focus entries | **Reject** with diagnostic |
| ChatTab.swift | **Delete** on A2; retain chat models |

## 13. Post-approval checklist

- [x] User approves this plan (forks locked §12; review edits applied)
- [x] Update [`focus-stack-delivery.md`](focus-stack-delivery.md) living status → Phase 4 Done + next-session prompt → Phase 5 A0
- [ ] Append **`docs/decisions.md`** row only when invariants discovered during implement (not for plan lock)

---

## 14. References

- Product: [`focus-stack.md`](focus-stack.md)
- Mocks: [`focus-stack-ad-tab-a.html`](../archive/design-mocks/focus-stack-ad-tab-a.html) · [`focus-stack-ad-detail-a.html`](../archive/design-mocks/focus-stack-ad-detail-a.html) · [`focus-stack-ad-sheets-a.html`](../archive/design-mocks/focus-stack-ad-sheets-a.html) · [`focus-stack-ad-library-chrome-a.html`](../archive/design-mocks/focus-stack-ad-library-chrome-a.html)
- Shipped anchors: [`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift) (Category row) · [`LibraryTab.swift`](../../Phathom/Phathom/Views/Library/LibraryTab.swift) (leading ReadStatus swipe)
- Tokens: [`docs/design-tokens.md`](../design-tokens.md)
