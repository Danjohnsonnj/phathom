# UI Evolution — Implementation Plan

> **Status:** **UI evolution rollout complete** (May 2026). Phases **0–4b** shipped. **Next:** product-directed work only — locked surfaces [§3–§12](library-ui-evolution.md); invariants in [`decisions.md`](../decisions.md) UI rows.
>
> **Authority:** **`Phathom/` code** > [`docs/decisions.md`](../decisions.md) > **this plan** > [`library-ui-evolution.md`](library-ui-evolution.md) > [`.design-mocks/`](../../.design-mocks/)
>
> **North star:** 22px rhythm · hairline gallery · editorial screen titles · filled cards for form/config only · preserved liquid-glass tab bar

**Discovery inputs:** Locked surfaces [§3–§3.10](library-ui-evolution.md) · [token sheet](ui-evolution-token-sheet.md) · six canonical HTML mocks (visual reference) · shipped [`Phathom/Phathom/Views/`](../../Phathom/Phathom/Views/)

**Anti-pattern:** Do not implement by walking `library-ui-evolution.md` surface-by-surface as a checklist. Follow phases below — shared foundation and rows first, then surfaces by dependency.

---

## 1. Mocks → SwiftUI + agent inference

HTML mocks are **visual reference only**. **Ship target is SwiftUI** in `Phathom/`. Extended prose: hand-off [§2.2](library-ui-evolution.md#22-html-mocks--swiftui-target) · [§2.3](library-ui-evolution.md#23-agent-inference-mocks-are-not-exhaustive).

### 1.1 What to translate

| Take from mocks | Do **not** port from HTML |
|-----------------|---------------------------|
| Spacing rhythm (22pt inset), palette, type scale, section order | DOM structure, CSS class names, Geist font |
| Hairline vs fill **decisions**, enabled/disabled CTA states | Device chrome (status bar, Dynamic Island, side-by-side frames) |
| Drawn states (Search active, pipeline in actions row, etc.) | Literal CSS (`position: fixed`, `backdrop-filter` copy-paste) |
| Look and feel alignment | Mock lorem / example URLs as product strings |

**SwiftUI idioms:** `TabView` liquid glass · `.safeAreaInset` · `NavigationStack` · `DisclosureGroup` · `LibraryFilterBar` **popover** (not `Menu`) · overlays for pinned search · `TextField`/`TextEditor`.

**Typography:** Geist in mocks → **SF Pro** at [token sheet](ui-evolution-token-sheet.md) sizes/weights.

**Behavior vs look:** Mock and **shipped code** disagree on **behavior** → code wins until hand-off updates. Mocks govern **look and feel** only.

Use *align with mock + locked §3* — not *port HTML* or *implement the mock*.

### 1.2 When the mock is silent

Sheets, modals, popovers, swipes, and navigation pushes are **not** fully drawn in HTML. Infer **in order**:

1. Locked **§3** table for the surface ([§3–§3.10](library-ui-evolution.md)).
2. **Shipped Swift** for that surface — preserve semantics unless hand-off changes UX.
3. **Related locked surface** (e.g. Detail highlight row → Notebook; Detail back → Settings).
4. [`docs/decisions.md`](../decisions.md).

| Rule | Action |
|------|--------|
| **Mock silent ≠ cut feature** | Shipped has it; hand-off does not reject → **keep behavior**; restyle to north star. |
| **Mock silent + out of scope** | Do not add (Chat RAG, Notebook search, etc.). |
| **Mock silent + unresolved** | Nearest locked surface + north star; note in PR if ambiguous. |
| **Cross-surface editors** | Tag edit, category, read status, summarize/archive — **Detail + Settings** only. |

**Unmocked examples (preserve + restyle):**

- **Library:** swipe read/archive, bulk bar, category picker sheet, Dive deeper, empty states, deep-link → Detail
- **Detail:** tag edit, category picker, highlight note sheet, related items, share, WebView hero
- **Settings:** model importers, test inference, export/import dialogs, Recently Deleted push
- **Add New:** `PhotosPicker`, save validation, mode pill above tab bar

**Material tie-breaker:** Browse/gallery → hairline, no fill. Form/config → filled `#403d39`. Primary capsule CTA → Add New Save only; Detail actions → hairline-bordered.

---

## 2. Planning locks (May 2026)

| Decision | Locked choice |
|----------|---------------|
| Library nav | **Drop `Phathom` principal** on tab roots; Detail push **back + share only** (no center wordmark) |
| Search dismiss | **Cancel** exits; **keyboard dismiss** only while active; no tap-outside |
| Pipeline control | **Actions row** trailing, before Search ([§3.2.1](library-ui-evolution.md#321-pipeline-control--actions-row-trailing)) |
| Rollout | **Per-phase green-light** before Swift |
| Typography | SF Pro at token-sheet scale — **fixed pt sizes** on editorial/zone chrome (`EditorialScreenTitle`, `ZoneSectionHeader`); not Dynamic Type–scaled (intentional editorial lock; revisit only on a11y audit) |

---

## 3. Rollout policy

```mermaid
flowchart TD
  planApprove[Plan approved]
  p0[Phase 0 Foundation]
  p1[Phase 1 Shared rows]
  p2[Phase 2 Library]
  p3a[Phase 3a Add New]
  p3b[Phase 3b Notebook]
  p3c[Phase 3c Chat]
  p4a[Phase 4a Detail]
  p4b[Phase 4b Settings]

  planApprove --> p0
  p0 -->|green-light| p1
  p1 -->|green-light| p2
  p2 -->|green-light| p3a
  p3a -->|green-light| p3b
  p3b -->|green-light| p3c
  p3c -->|green-light| p4a
  p4a -->|green-light| p4b
```

**Gate:** User says **green-light Phase N** before Swift for that phase only.

**Verify ladder** ([`simulator-verify.mdc`](../../.cursor/rules/simulator-verify.mdc)):

1. ReadLints on touched `.swift`
2. `bash scripts/build-phathom.sh sim`
3. `bash scripts/test-phathom.sh` (full `PhathomTests`; `--grep` subset OK for UI-only)

**Manual sim (required):** Library search overlay · filter popovers (including **while list scrolled**) · bulk select · Settings disclosure states (Configured / Primary unset / Missing file).

**Tab-root scroll inset:** Tab surfaces with editorial scroll apply **`.contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)`** so content clears the liquid-glass tab bar (~104pt). **Library** is the reference impl (Phase 2); **Phases 3a–3c** wire in the owning phase.

**Tab-root scroll top inset:** Editorial tab roots use **~12pt** padding above the first chrome block (Library, Add New) unless a surface mock specifies otherwise (Settings **~4pt** → Phase 4b).

After each shipped phase: append UI commitments to [`docs/decisions.md`](../decisions.md); optionally sync **`library-ui-evolution.md`** shipped/resolve rows when closeout review-plan finds drift.

### Post-phase closeout (Phases 3b–4b)

After Swift for a phase passes the verify ladder (+ manual sim when the phase checklist requires it), run this **closeout loop** before marking the phase shipped and stopping:

1. **Build** — `ReadLints` → `bash scripts/build-phathom.sh sim` → `bash scripts/test-phathom.sh`
2. **Code review** — [`code-review`](../../.cursor/skills/code-review/SKILL.md) in a **readonly subagent**; compare diff to that phase’s plan section + locked §3 + canonical mock
3. **Fix** — address **Critical** and **Warning** items specific to the phase, plus items that help later phases; skip mock micro-polish unless user asks
4. **Review-plan** — [`review-plan`](../../.cursor/skills/review-plan/SKILL.md) on **remaining** review feedback; triage against plan gates; **propose** plan/doc updates
5. **Await user** — apply approved plan edits only after explicit yes; then update status, green-light boxes, cold start, and `decisions.md`

**Do not** skip closeout to jump to the next phase. **Do not** apply plan edits in the same turn as the triage report.

---

## 4. Phase summary

| Phase | Goal | Depends on |
|-------|------|------------|
| **0** | Tokens + shared chrome primitives | Plan approved |
| **1** | Extract row/control types (no surface swap) | 0 |
| **2** | Library — unified scroll, Search B, gallery | 0, 1 |
| **3a** | Add New tab | 0 |
| **3b** | Notebook tab | 0, 1 |
| **3c** | Chat placeholder | 0 |
| **4a** | Detail push | 0, 1 |
| **4b** | Settings push | 0 |

---

## 5. Phase 0 — Foundation

**Goal:** `AppSpacing`, `AppPalette.hairline`, editorial/zone header helpers.

**Files:**

- `Phathom/Phathom/Helpers/AppSpacing.swift` — `screenHorizontal = 22`, gaps from [token sheet §3](ui-evolution-token-sheet.md#3-spacing--layout-rhythm)
- [`AppPalette.swift`](../../Phathom/Phathom/Helpers/AppPalette.swift) — `hairline`
- `Phathom/Phathom/Views/Shared/EditorialScreenTitle.swift`
- `Phathom/Phathom/Views/Shared/ZoneSectionHeader.swift` — reuse/extend [`DetailAISubsectionHeader`](../../Phathom/Phathom/Views/Detail/DetailSectionHeader.swift) for child tier
- `Phathom/Phathom/Views/Shared/DetailBackBarButton.swift`
- Register new files in **`Phathom.xcodeproj`** target `Phathom`

**Risks:** Low.

**Green-light:**

- [x] `AppSpacing.screenHorizontal == 22`
- [x] `AppPalette.hairline` defined
- [x] Shared views compile; Xcode target updated
- [x] No tab surface layout changes

### Phase 0 → wiring contracts {#phase-0-wiring-contracts}

Shared views **defer layout the parent owns** — wire in the owning phase below.

| Component | Owned by shared view | **Call site owns** (phase) |
|-----------|-------------------|---------------------------|
| **`EditorialScreenTitle`** | 34pt semibold title + default **`editorialTitleBottom` (28pt)** | Horizontal **`AppSpacing.screenHorizontal`** · **top inset** (tab roots **~12pt** — [§3](#3-rollout-policy); Settings **~4pt** → Phase 4b) · when parent **`VStack`** owns title→content gap via **`sectionVerticalGap`**, pass **`bottomSpacing: 0`** (Add New Phase 3a; avoid double 28+24) |
| **`ZoneSectionHeader`** | 17pt **semibold** title + optional 15pt subtitle | **8pt** gap before grouped content (Settings Phase 4b) · subsection tier stays **`DetailAISubsectionHeader`** (Phase 4a) |
| **`DetailBackBarButton`** / **`DetailBackBarToolbarItem`** | Accent chevron, `.plain`, default `dismiss()` — **no** liquid-glass capsule (**`.sharedBackgroundVisibility(.hidden)`** on toolbar item) | **`DetailBackBarToolbarItem`** in `.toolbar` · **`.navigationBarBackButtonHidden(true)`** on push host · **~44pt** min row · optical sim (Detail, Settings) |
| **`HairlineHighlightRow`** | 4px bar, italic quote (primary), uppercase **Note** label | Note body **secondary** (mock) · horizontal inset on parent · **`showsBottomHairline: false`** on last row in a section (Detail Phase 4a) or between highlights on same Notebook item (Phase 3b) · **`verticalPadding`** (Detail **16pt** default; Notebook feed **0** + parent **`AppSpacing.highlightStackGap`**) |

**Typography tie-breakers (Phase 4+):**

- Zone parent weight: **semibold** (token sheet §4) — not §3.6 prose “bold”.
- Settings editorial title bottom: **28pt** (`AppSpacing.editorialTitleBottom`) — not settings mock `section-gap` (24px).
- `filterColumnSplit` (27.5 / 27.5 / 45): stays in **`LibraryFilterBar`** only — see `AppSpacing` comment; do not add CGFloat constants (Phase 2).

---

## 6. Phase 1 — Shared row components

**Goal:** New types only — **no call-site swaps** until owning phase.

**Extract (keep existing types until wired):**

| New type | Source / notes |
|----------|----------------|
| `HairlineHighlightRow` | §3.6/§3.8 — 4px bar, italic quote, uppercase **Note**; note body secondary; line-limit params |
| `GalleryListRow` | Library gallery — hairline, 64×64 thumb (shipped `ContentCardRow` uses 76) |
| `LibraryPipelineControlButton` | From [`LibraryTab`](../../Phathom/Phathom/Views/Library/LibraryTab.swift) — wire Phase 2 |
| `PinnedLibrarySearchBar` | Shell — wire Phase 2 |

**Wiring schedule:**

| Component | Call site | Phase |
|-----------|-----------|-------|
| `GalleryListRow` | `LibraryTab` | 2 |
| `ContentCardRow` | `RelatedItemsSheet`, `RecentlyDeletedView` | Unchanged |
| `HairlineHighlightRow` | `HighlightsNotesSection`, `HighlightNoteEditSheet` preview | 4a ✓ |
| `HairlineHighlightRow` | `NotebookItemGroup` | 3b ✓ |
| `HighlightCardView` | — | Unwired (superseded by `HairlineHighlightRow`; file may remain) |

**Green-light:**

- [x] New types compile + in Xcode target
- [x] Shipped surfaces visually unchanged
- [x] Wiring schedule honored (no early swaps)

---

## 7. Phase 2 — Library (highest risk)

**Goal:** Align with [`library-ad-search-b-toolbar.html`](../../.design-mocks/library-ad-search-b-toolbar.html) + [§3.1–§3.2.1](library-ui-evolution.md#3-locked-decisions-library) — SwiftUI, not HTML port.

**Primary file:** [`LibraryTab.swift`](../../Phathom/Phathom/Views/Library/LibraryTab.swift)

**Tasks:**

- Remove `.searchable`; **net-new Search** in actions row → pinned overlay
- Actions row: Select · Pipeline · Search · Settings (Done during bulk edit)
- Drop `Phathom` principal + duplicate `navigationTitle("Library")`
- Unified scroll (chrome + rows); keep `LibraryFilterBar` **popover**
- Wire **`EditorialScreenTitle("Library")`** — **`AppSpacing.screenHorizontal`** + **~12pt top** on editorial block (mock `screen-title` margin-top)
- 22pt inset; `GalleryListRow`; pipeline in actions row
- Search: Cancel exits; keyboard dismiss only while active

**Wiring mechanics** (Phase 1 components → `LibraryTab`):

- **`GalleryListRow`**: replace row body inside existing **`libraryItemRow`** shell — preserve `NavigationLink`, swipes, bulk select, a11y
- **List insets**: zero horizontal **`listRowInsets`** on gallery rows (`GalleryListRow` already applies **`AppSpacing.screenHorizontal`** — avoid double 16+22 inset)
- **`showsBottomHairline`**: `false` on each section’s **last** row (mock `:last-child`)
- **`LibraryPipelineControlButton`**: delete nested **`LibraryPipelineControl`** in `LibraryTab`; use module enum + extracted button
- **`PinnedLibrarySearchBar`**: overlay above scroll (material/blur per mock, **~8pt** vertical bar padding); **hide** pipeline + actions row under search; dim list chrome (mock `.gallery-list--dimmed`); keyboard swipe-down dismisses keyboard **only** — not search mode
- **Search open**: `ScrollViewReader` scrolls to actions-row anchor (mock Search active frame at top)
- **Cancel**: exits search overlay only — **retains query** (distinct from keyboard dismiss while active)
- **Tab bar scroll inset**: `.contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)` on tab-root scroll (Library reference; Phases 3a–3c in owning phase)
- **Optional**: shared `chipAction` helper if touching [`ContentCardRow`](../../Phathom/Phathom/Views/Library/ContentCardRow.swift) during wire (avoid duplicating retry/ingest logic)

**Preserve (inference §1.2):** [`LibrarySearchService`](../../Phathom/Phathom/Services/LibrarySearchService.swift), Dive deeper, swipes, bulk select, filter 27.5/27.5/45, Settings push, category sheet, deep links.

**Risks:** High — scroll-under search, edit mode, popovers, `navPath`, bulk inset + tab bar ~104pt.

**Green-light:**

- [x] At rest + Search active align with mock + §3
- [x] Unmocked flows work (swipes, bulk, category sheet, pipeline)
- [x] Cancel / keyboard dismiss correct
- [x] No `LibrarySearchService` semantic changes

---

## 8. Phase 3a — Add New

**Goal:** [§3.7](library-ui-evolution.md#37-locked-decisions-add-new) — 22px inset, capsule Save, drop hints.

**File:** [`AddNewTab.swift`](../../Phathom/Phathom/Views/AddNew/AddNewTab.swift)

**Tasks:** inset 16→22 · Save capsule · remove `processingHint` · Note editor no placeholder · Web/Photo placeholders per §3.7

**Wiring mechanics:**

- **`EditorialScreenTitle("Save", bottomSpacing: 0)`** — parent **`VStack(spacing: AppSpacing.sectionVerticalGap)`** owns 24pt title→card and card→Save rhythm (mock `add-new-stack` gap); do **not** stack default 28pt title bottom + section gap
- **Scroll top inset ~12pt** on editorial content (see [§3 tab-root scroll top inset](#3-rollout-policy))
- **`tabBarScrollInset`** via `.contentMargins(.bottom, …, for: .scrollContent)` on `ScrollView`

**Preserve:** mode pill, capture save rules, tab bar inset via **`AppSpacing.tabBarScrollInset`** (see [§3 tab-root scroll inset](#3-rollout-policy); Library reference).

**Green-light:**

- [x] Six mock states (Web · Note · Photo × Starting / Filled) · capsule Save enabled/disabled · no processing footnotes
- [x] Manual sim: mode pill · Save capsule states · scroll clears tab bar + mode bar

---

## 9. Phase 3b — Notebook

**Goal:** [§3.8](library-ui-evolution.md#38-locked-decisions-notebook) — editorial scroll, hairline highlights, inter-group rules.

**Files:** [`NotebookTab.swift`](../../Phathom/Phathom/Views/Notebook/NotebookTab.swift), [`NotebookItemGroup.swift`](../../Phathom/Phathom/Views/Notebook/NotebookItemGroup.swift)

**Tasks:** `EditorialScreenTitle` · drop nav duplicate · surface-appropriate **top inset** per mock · `HairlineHighlightRow` (3/2 limits, **`showsBottomHairline: false`** between highlights on same item) · header thumb 48→64 · title paprika→primary · inter-group hairline only · inset 22 · **`tabBarScrollInset`** on scroll (see §3)

**Preserve:** [`NotebookHighlightsQuery`](../../Phathom/Phathom/Services/NotebookHighlightsQuery.swift), Detail push, [`HighlightNoteEditSheet`](../../Phathom/Phathom/Views/Detail/HighlightNoteEditSheet.swift), empty copy.

**Green-light:**

- [x] No paprika parent title · 64×64 thumb · separator rules · empty copy unchanged
- [x] Unified scroll · `EditorialScreenTitle` · no `Phathom` principal · `tabBarScrollInset`
- [x] `HairlineHighlightRow` in feed (`showsBottomHairline: false` within item)

**Shipped notes (closeout):**

- **Empty state:** 17pt semibold title + 15pt hint; **24pt** bottom padding only — no extra top pad beyond `EditorialScreenTitle` **28pt** (see [`notebook-ad-hairline-feed-a.html`](../../.design-mocks/notebook-ad-hairline-feed-a.html) Empty frame).
- **Group header subtitle:** kind line (`Photo` / `Note` / host) per [§3.8](library-ui-evolution.md#38-locked-decisions-notebook) — **not** `GalleryListRow.sourceLine` (summary/media description).

---

## 10. Phase 3c — Chat placeholder

**Goal:** [§3.9](library-ui-evolution.md#39-locked-decisions-chat-placeholder) — editorial **Chat** + two-tier copy.

**File:** [`ChatTab.swift`](../../Phathom/Phathom/Views/Chat/ChatTab.swift)

**Out of scope:** [`phase-3-rag-chat.md`](phase-3-rag-chat.md)

**Tasks:** `EditorialScreenTitle("Chat")` · **`AppSpacing.screenHorizontal`** · top inset per mock · two-tier empty copy · **`tabBarScrollInset`** on scroll (see §3)

**Empty parity:** Match [§9 shipped empty typography](#9-phase-3b--notebook) + [§3.9](library-ui-evolution.md#39-locked-decisions-chat-placeholder) + [`notebook-ad-hairline-feed-a.html`](../../.design-mocks/notebook-ad-hairline-feed-a.html) Empty frame (editorial title → 17/15pt tiers; no card/hairline box).

**Green-light:**

- [x] Editorial title in scroll · left-aligned copy · no fake chat UI
- [x] **`EditorialScreenTitle("Chat")`** · **`AppSpacing.screenHorizontal`** · **12pt** top · **`tabBarScrollInset`**
- [x] Two-tier copy (17pt semibold + 15pt hint); no `navigationTitle` duplicate

---

## 11. Phase 4a — Detail

**Goal:** [§3.6](library-ui-evolution.md#36-locked-decisions-detail) — hairline material, AI zone Option 5, 22px inset.

**Files:** [`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift), [`HighlightsNotesSection.swift`](../../Phathom/Phathom/Views/Detail/HighlightsNotesSection.swift), [`HighlightNoteEditSheet.swift`](../../Phathom/Phathom/Views/Detail/HighlightNoteEditSheet.swift), section views as needed

**Tasks:** `HairlineHighlightRow` in highlights + sheet preview · replace divider with **`ZoneSectionHeader`** (semibold parent, not §3.6 “bold”) · **`DetailBackBarButton`** + **`.navigationBarBackButtonHidden(true)`** — verify single accent chevron + **~44pt** row in sim · hairline sections · processing badge placement preserved

**Preserve:** back **navigation** (custom chevron, not system back label) · flat share · section order · all sheets/flows (inference §1.2). **No** center **Phathom** wordmark (removed — was mock mistake).

**Green-light:**

- [x] No filled highlight/summary cards · AI zone Option 5 · highlight tap + edit sheet
- [x] **`HairlineHighlightRow`** in highlights + sheet preview · **`ZoneSectionHeader("AI analysis")`** replaces divider
- [x] **`DetailBackBarButton`** leading + **`.navigationBarBackButtonHidden(true)`** · **22pt** inset · hairline sections · action buttons hairline-bordered
- [x] Back + flat share only (no center wordmark) · processing badge placement unchanged

**Shipped notes (closeout):** **`DetailAIAnalysisDivider.swift`** removed (unwired). Post-rollout polish: no center **Phathom** wordmark; **`DetailPushNavBar`** (22pt inset, mock `.detail-nav`) replaces toolbar back/share; **`detailSectionAfterHairlineGap` (20pt)** on action block (was incorrect 8pt in mock). Detail header **snippet** removed — host · title · timestamp only; mock + §3.6 updated.

---

## 12. Phase 4b — Settings

**Goal:** [§3.10](library-ui-evolution.md#310-locked-decisions-settings) — editorial **Settings**, back-only push, demoted zone headers.

**File:** [`SettingsTab.swift`](../../Phathom/Phathom/Views/Settings/SettingsTab.swift) (`SettingsContent` — pushed from Library)

**Tasks:** **`EditorialScreenTitle("Settings")`** — **`AppSpacing.screenHorizontal`**, **~4pt top**, **28pt bottom** (token sheet, not mock 24px) · **`DetailBackBarButton`** + **`.navigationBarBackButtonHidden(true)`** back-only nav · **`ZoneSectionHeader`** zone headers + **8pt** gap before grouped card · 22px inset · filled grouped surfaces

**Preserve:** full IA, disclosures, importers, backup flows (inference §1.2; mock frames Configured / Primary unset / Missing file).

**Green-light:**

- [x] Back-only nav (`DetailBackBarButton` + hide system back) · zone typography · all disclosure/sheet flows intact
- [x] **`EditorialScreenTitle("Settings")`** · **22pt** inset · **~4pt** top · **28pt** title bottom (nested `VStack`, not 52pt double gap)
- [x] **`ZoneSectionHeader`** + **8pt** pre-card · filled grouped surfaces · IA / disclosures / importers / backup unchanged

**Shipped notes (closeout):** Title→sections use outer `VStack(spacing: 0)` + inner `sectionVerticalGap` (closeout spacing fix). **`AppAppearance`**: `nav.shadowColor = .clear` (removes push nav hairline; app-wide). **`SettingsContent`**: `toolbarBackground(AppPalette.background)` on push host. **`SettingsSectionHeader`** removed. Recently Deleted nested push chrome deferred.

---

## 13. Out of scope

- Chat RAG ([`phase-3-rag-chat.md`](phase-3-rag-chat.md))
- Share extension UI · CloudKit/sync CTAs · tab bar redesign
- `LibraryFilterBar` column proportion change
- Literal HTML/CSS/DOM port

---

## 14. Related documents

| Doc | Role |
|-----|------|
| [`library-ui-evolution.md`](library-ui-evolution.md) | Locked §3 per-surface decisions |
| [`ui-evolution-token-sheet.md`](ui-evolution-token-sheet.md) | Tokens, material matrix, shared components |
| [`.design-mocks/README.md`](../../.design-mocks/README.md) | Mock inventory |
| [`docs/decisions.md`](../decisions.md) | Product invariants — update per shipped phase |
| [`AGENTS.md`](../../AGENTS.md) | Agent entry map |

**Canonical mocks:** `library-ad-search-b-toolbar` · `detail-ad-full-hairline-a` · `add-new-ad-filled-card-a` · `notebook-ad-hairline-feed-a` · `chat-ad-placeholder-a` · `settings-ad-grouped-a`

---

## 15. Cold start & rollout status {#15-cold-start--rollout-complete}

**UI evolution rollout complete** (May 2026). Phases **0–4b** shipped in Swift. Do **not** re-run surface swaps without product direction. New UI work: **`Phathom/`** + [`decisions.md`](../decisions.md) UI rows + locked [§3–§3.10](library-ui-evolution.md).

**Historical cold-start blocks:** archived below (Phase 4b → 4a → …). Stale links to `#15-cold-start--phase-0` should resolve here.

### Archive — Phase 4b cold start

```
GOAL: UI evolution Phase 4b — Settings push surface swap. Wire Phase 0 editorial + zone chrome.
ENV: iOS 26 / Swift 6 / SwiftUI | repo:phathom

READ (minimal):
  1. docs/handoff/ui-evolution-implementation-plan.md §12 + [Phase 0 wiring contracts](#phase-0-wiring-contracts)
  2. docs/handoff/library-ui-evolution.md §3.10
  3. .design-mocks/settings-ad-grouped-a.html (visual reference)
  4. Phathom/Phathom/Views/Settings/SettingsTab.swift

WIRE (Phase 4b):
  - EditorialScreenTitle("Settings") · screenHorizontal · ~4pt top · 28pt bottom
  - DetailBackBarButton + .navigationBarBackButtonHidden(true) back-only · ZoneSectionHeader zone headers · 8pt gap before grouped cards
  - 22pt inset · filled grouped surfaces preserved

DO NOT: tab bar redesign · literal HTML port · disclosure IA changes

VERIFY: ReadLints → bash scripts/build-phathom.sh sim → bash scripts/test-phathom.sh
  Manual sim: back-only nav · zone typography · Configured / Primary unset / Missing file frames

GREEN-LIGHT DONE WHEN: §12 green-light checklist passes

THEN: Stop. UI evolution rollout complete.

AUTHORITY: code > decisions.md > this plan > library-ui-evolution.md > mocks
```

(Phase 4b complete — see §12 green-light.)

### Archive — Phase 4a cold start

```
GOAL: UI evolution Phase 4a — Detail push surface swap.
... (Phase 4a complete — see §11 green-light)
```

### Archive — Phase 3c cold start

```
GOAL: UI evolution Phase 3c — Chat tab placeholder surface swap.
... (Phase 3c complete — see §10 green-light)
```

### Archive — Phase 3a cold start

```
GOAL: UI evolution Phase 3a — Add New tab surface swap.
... (Phase 3a complete — see §8 green-light)
```

### Archive — Phase 2 cold start

```
GOAL: UI evolution Phase 2 — Library surface swap (highest risk). Wire Phase 0–1 components.
... (Phase 2 complete — see §7 green-light)
```

### Archive — Phase 1 cold start

```
GOAL: UI evolution Phase 1 — Shared row components. NO surface swaps.
... (Phase 1 complete — see §6 green-light)
```
