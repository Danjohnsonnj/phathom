# Design tokens

> **Role:** Cross-surface **spacing, type, palette, material, and button** reference distilled from locked discovery ([`archive/library-ui-evolution.md`](archive/library-ui-evolution.md) §3–§3.10 + §4). Semantic matrix + shared component index — not a build spec; per-surface locks stay in archive §3 tables.
>
> **Status:** Live reference (May 2026 UI evolution shipped). **`AppSpacing`** / **`AppPalette`** in code are authoritative for token **values**; this doc is authoritative for **semantics** and component vocabulary.
>
> **Use with:** Canonical mocks in [`archive/design-mocks/`](archive/design-mocks/) · shipped code in **`Phathom/`** · [`AppPalette.swift`](../../Phathom/Phathom/Helpers/AppPalette.swift)

---

## 1. Authority & scope

| Layer | Purpose |
|-------|---------|
| **[`archive/library-ui-evolution.md`](archive/library-ui-evolution.md)** | Locked per-surface decisions, behavior, mocks, rejections |
| **This doc** | Cross-surface tokens + chrome/material matrix + shared components |
| **Implementation plan** | [`archive/ui-evolution-implementation-plan.md`](archive/ui-evolution-implementation-plan.md) — **shipped** Phases 0–4b |
| **`Phathom/` code** | Authoritative for spacing/token drift vs this sheet |

**Do not** re-run phase surface swaps from the archived plan. New UI work: code + [`decisions.md`](decisions.md) UI rows + [`archive/library-ui-evolution.md`](archive/library-ui-evolution.md) §3.

---

## 2. Palette

Palette **unchanged** — refine execution only. Map to existing `AppPalette` unless a new semantic token is justified.

| Token | Hex | `AppPalette` / use |
|-------|-----|-------------------|
| **Background** | `#252422` | `background` — screen base |
| **Surface** | `#403d39` | `surface` — grouped cards, thumbs fallback, filter capsules |
| **Surface nested** | `#353330` | `surfaceNested` — field wells, icon wells, disabled Save, archived badge |
| **Accent** | `#eb5e28` | `accent` — paprika: select, cancel, active tab, unread dot, search focus, disclosure tint |
| **Text primary** | `#fffcf2` | `textPrimary` |
| **Text secondary** | `#ccc5b9` | `textSecondary` |
| **Text tertiary** | ~72% dust | `textTertiary` — disabled/meta |
| **Chip / badge bg** | `#401F12` | `metaChipBackground` — processing badge, tag chips (Detail) |
| **Tag chip bg** | `#401F12` | `tagChipBackground` (= `metaChipBackground`) — Detail tags; **primary** label |
| **Hairline** | `rgba(255,252,242,0.12)` | Row/section dividers — `AppPalette.hairline` |
| **Success / warning** | System green / orange | Model status icons, missing-file copy (Settings) — keep system semantic colors |

---

## 3. Spacing & layout rhythm

| Token | Value | Use |
|-------|-------|-----|
| **`screenHorizontal`** | **22pt** | Default content inset — tab roots, Detail, Add New, Notebook, Chat, Settings (up from shipped 16pt where noted) |
| **`sectionVerticalGap`** | **24pt** | Between major section groups (Settings zones, Add New stack) |
| **`editorialTitleBottom`** | **~28pt** | Margin below screen-owned large title before first section |
| **`aiSubsectionHairlineGap`** | **22pt** | Detail AI zone: last tag or summary bullet → hairline, and hairline → next subsection header |
| **`detailSectionAfterHairlineGap`** | **20pt** | Detail hairline sections: content below top hairline (spaced blocks, action CTAs). Matches last Key Figures row → action hairline (ai-zone bottom padding) |
| **`pushNavBarTop`** / **`pushNavBarBottom`** | **4pt** / **8pt** | Pushed Detail / Settings nav chrome (mock `.detail-nav`); horizontal = **`screenHorizontal`** |
| **`tabBarScrollInset`** | **~104pt** | Bottom padding so list scrolls under liquid-glass tab bar |
| **`galleryRowVertical`** | **~19pt** | Library gallery row padding |
| **`highlightStackGap`** | **~14pt** | Vertical gap between highlights **within** same Notebook item (no hairline) |
| **`filterBarHeight`** | **72pt** | Library `LibraryFilterBar` stable height |
| **`filterColumnSplit`** | **27.5% / 27.5% / 45%** | Library filters (minus 10pt gaps) — **do not change** |
| **`cardCornerRadius`** | **14pt** | Grouped Settings surfaces, Add New capture card |
| **`thumbCornerRadius`** | **6pt** | Library / Notebook 64×64 thumbs |
| **`capsuleCTAHeight`** | **50pt** min | Add New Save, Detail Visit Site pill |
| **`modePillOuterRadius`** | **~26pt** | Add New segmented mode bar (+ 4pt inner inset) |

---

## 4. Typography (SF Pro)

Mocks use **Geist**; ship **SF Pro** at equivalent sizes/weights. Suggested SwiftUI mapping:

| Role | Size / weight | SwiftUI (approx.) | Surfaces |
|------|---------------|-------------------|----------|
| **Screen title** | 34pt semibold, tight tracking | `.largeTitle` + `.fontWeight(.semibold)` or custom 34 | Library, Notebook, Save, Chat, Settings |
| **Zone header** | 17pt semibold | `.headline` / custom 17 semibold | Detail AI analysis parent; Settings AI Models / Library / Data |
| **Zone subtitle** | 15pt regular, secondary | `.subheadline` + secondary | Settings section subtitles |
| **Subsection header** | 15pt medium, secondary | Custom — Detail Tags/Summary/Key Figures | Detail AI zone children |
| **Gallery title** | 16pt medium | `.callout` + medium | Library row, Notebook group header |
| **Source / kind line** | 13pt secondary | `.footnote` + secondary | Library, Notebook header |
| **Empty primary** | 17pt semibold | `.headline` | Notebook empty, Chat coming-soon |
| **Empty hint** | 15pt secondary, ~32ch | `.subheadline` + secondary | Notebook empty, Chat hint |
| **Meta / date** | 12pt muted | `.caption` + tertiary | Library row meta |
| **Disclosure label** | Subheadline semibold | `.subheadline.weight(.semibold)` | Settings model rows (preserve) |
| **Body / actions** | 17pt body | `.body` | Settings rows, Export/Import |
| **Footnote / footer** | Footnote secondary | `.footnote` + secondary | Settings footer, model info |
| **Filter labels** | Static above capsules | Shipped `LibraryFilterBar` | Library only |

**Links:** No underline — SwiftUI `NavigationLink` / plain buttons; mocks use `a { text-decoration: none }`.

---

## 5. Material language

Decision tree for list/form surfaces:

```
Content type?
├─ Browse / gallery lists (Library, Notebook headers)
│  └─ Hairline rows, NO fill — 1px hairline between rows/groups
├─ Article / reading (Detail body, highlights, summary)
│  └─ Hairline sections — NO filled card wrappers (Detail A)
├─ Form / config density (Add New capture, Settings disclosures)
│  └─ Filled #403d39 grouped surface + #353330 nested wells
└─ Primary action on form screen
   └─ Filled paprika capsule (Add New Save only on that screen)
```

| Pattern | Fill | Dividers | Surfaces |
|---------|------|----------|----------|
| **Gallery hairline** | None | Full-width hairline between rows/groups | Library list, Notebook inter-group |
| **Detail hairline** | None | Hairline between highlight rows in section | Detail highlights |
| **Notebook intra-item** | None | **No** hairline — 14pt gap only | Notebook highlights same parent |
| **Grouped config card** | `#403d39`, 14pt radius | Inset hairline between rows | Settings |
| **Capture card** | Outer `#403d39` + inner `#353330` wells | Internal well borders | Add New |
| **Detail actions** | None | Hairline-bordered **capsule** buttons; **20pt** below section hairline (parity with Key Figures → line) | Detail bottom |
| **Tag chips** | `#401F12` capsule, **primary** text (13pt medium) | No enclosing card | Detail |

**Highlight row (shared):** 4px left paprika bar · italic quote · uppercase **Note** when present · one component for Detail + Notebook.

### 5.1 Button shapes & variants

All tappable full-width actions use **`Capsule()`** geometry unless listed as an exception below.

| Variant | Shape | Fill | Stroke | Min height | Examples |
|---------|-------|------|--------|------------|----------|
| **Primary capsule** | `Capsule()` | `accent` | none | 50pt when full-width | Add New Save |
| **Primary capsule (compact)** | `Capsule()` | `accent` | none | content + 10×28 pad | Detail Visit Site |
| **Secondary hairline capsule** | `Capsule()` | transparent | `hairline` 1pt | content + 12×16 pad | Detail Summarize / Archive — **`HairlineCapsuleButton`** |
| **Filled secondary capsule** | `Capsule()` | `surfaceNested` | none | content + 12 vertical pad | Library bulk Mark as… / Archive; Highlight Delete note |
| **Mode pill shell** | ~26pt continuous rect | `surface` | none | 52pt | Add New mode bar |
| **Read status** | System `UISegmentedControl` | system | **none** — no overlay stroke | system | Detail New/Read/Filed |
| **Flat toolbar text** | System toolbar label | transparent | none | system toolbar | Close, Cancel, Done — **`FlatToolbarTextItem`** |

**Documented exceptions (not capsule buttons):**

- System `.bordered` destructive (Highlight Remove highlight)
- Input wells / TextEditor chrome — use `cardCornerRadius` / nested well tokens, not capsule

**Anti-pattern:** Do **not** overlay hairline strokes on system controls (`Picker.segmented`, `UISegmentedControl`) — causes double-ring artifacts against native chrome.

**Label fidelity (buttons / CTAs):** Interactive button and toolbar strings must display **in full** — no tail ellipsis (`…`) on the visible label.

- **Toolbar / chrome text** — `Text(...).fixedSize(horizontal: true, vertical: false)` via **`phathomToolbarTextLabel()`** in [`PhathomButtonLabelModifiers.swift`](../../Phathom/Phathom/Helpers/PhathomButtonLabelModifiers.swift) (`FlatToolbarTextButton`, Library Select/Cancel, search overlay Cancel, etc.).
- **Full-width capsule CTAs** — allow multi-line wrap; forbid `.truncationMode(.tail)` on label `Text` — **`phathomCapsuleCTALabel()`** (`HairlineCapsuleButton`, filled secondary capsules).
- **Filter value capsules** — tappable controls; same rule; column widths must fit longest value (**Uncategorized**) per Library §3.2.

---

## 6. Chrome patterns

| Context | Nav | Screen title | Tab bar | Scroll |
|---------|-----|--------------|---------|--------|
| **Tab root** (Library, Notebook, Chat, Add New) | Drop duplicate `navigationTitle`; Library: **no `Phathom` principal** — actions row only | Editorial **large title in scroll** | Liquid glass §3.5 | Unified — title scrolls with content |
| **Detail push** | Back + share only (no center wordmark) | None (article content) | Toolbar visible | Content scroll |
| **Settings push** | **Back only** (Detail back styling) | Editorial **Settings** in scroll | Hidden | Unified; back fixed above scroll |
| **Library at rest** | Select · Pipeline · Search · Settings | **Library** editorial | Visible | Unified |
| **Library search active** | Pinned search over actions band (pipeline hidden) | Same | Visible | Content scrolls under pinned bar |
| **Sheet / modal toolbar** | Flat accent/destructive text (**Close** form editors · **Cancel** / **Done** pickers · **Done** diagnostics) | Inline `navigationTitle` | System nav visible | Sheet body scrolls |

**Tab bar (preserved):** Library · Notebook · Chat · Add new — do not redesign.

**Push vs sheet toolbar:** Custom **`DetailPushNavBar`** in **`.safeAreaInset`** is already flat (no modifier). System **`NavigationStack` `.toolbar`** text/icon items require **`.sharedBackgroundVisibility(.hidden)`** via **`FlatToolbarTextItem`** (iOS 26 liquid-glass off).

### 6.1 Editor, picker & diagnostic sheets

Three families for all `.sheet(` presentations in **`Phathom/`**. Cross-link §5.1 (capsule CTAs; bordered destructive only for highest-severity actions — highlight **Remove highlight**).

#### Inventory

| Surface | Component | Family | Call sites |
|---------|-----------|--------|------------|
| Detail, Notebook | **`HighlightNoteEditSheet`** | Form editor | `DetailView`, `NotebookTab` — **`phathomSheetPresentation()`** |
| Detail | **`TagEditSheet`** | Form editor | `DetailView` — **`phathomSheetPresentation()`** |
| Detail, Library | **`CategoryPicker`** | List picker | `DetailView` ×2, `LibraryTab` swipe + bulk — unified shell |
| Detail | **`RelatedItemsSheet`** | List picker | `DetailView` — unified shell |
| Settings | **`importErrorDetailsSheet`** (`SettingsTab`) | Read-only diagnostic | `SettingsTab` — unified shell |

*Push only:* **`RecentlyDeletedView`** — not a sheet.

**All five sheet roots** above use the **unified shell** + measured detents (§ below). Do not add per-sheet detent logic.

#### Sheet sizing

Canonical implementation: [`PhathomSheetPresentation.swift`](../../Phathom/Phathom/Helpers/PhathomSheetPresentation.swift). All sheet roots use the **unified shell** on outermost **`NavigationStack`**:

```text
NavigationStack {
  ScrollView {
    VStack | LazyVStack  // sheet body
      .fixedSize(horizontal: false, vertical: true)
      .phathomSheetHeightMeasurable()
  }
  // .background, .navigationTitle, .toolbar on ScrollView
}
.phathomSheetPresentation()
```

- **Measure** — inner **`VStack` / `LazyVStack` only** (never `NavigationStack`, never outer `ScrollView`). Always **`fixedSize(horizontal: false, vertical: true)`** on the measure stack.
- **Initial height** — measured **`.height`** detent from `SheetContentHeightKey` preference + constants below.
- **Overflow** — internal **`ScrollView`** scrolls when content exceeds cap (sheet stays at cap height; body scrolls inside).
- **Drag** — **`.presentationDetents([.height(…), .large])`** + drag indicator; programmatic height updates pause after user drags to **`.large`** (`userExpandedToLarge` in helper).
- **API** — **`phathomSheetHeightMeasurable()`** on measure stack; **`phathomSheetPresentation()`** on **`NavigationStack`** only. No other sheet sizing modifiers.
- **Parents** — `.sheet { }` call sites do **not** set detents or sizing.

**Helper constants** (`PhathomSheetMetrics` — single source in helper file):

| Constant | Value | Role |
|----------|-------|------|
| `navBarAllowance` | **56pt** | Added to reported stack height for inline nav bar |
| `minSheetHeight` | **200pt** | Floor (avoids zero-height flash on first layout) |
| `maxSheetHeight` | **92%** of screen height | Cap; content scrolls inside beyond this |

**Anti-patterns (sheet sizing):**

- **`presentationSizing(.fitted…)`** alone — does not set initial detent when paired with only **`.large`**; sheets open full screen.
- **`frame(maxHeight: .infinity)`** on sheet root — fights content-fit detents.
- Detents or sizing on **`.sheet { }`** parents — double-application / fighting helper.
- Measuring **`NavigationStack`** or outer **`ScrollView`** — wrong height (always use inner stack).
- Native **`List`** on picker sheets — breaks unified measurement; use **`ScrollView` → `LazyVStack`** (**`CategoryPicker`**).
- Per-sheet custom detent math outside **`PhathomSheetPresentation.swift`**.

**`TextEditor` note:** intrinsic height often under-reports; if form-editor CTAs clip at open, measure a wrapper that includes explicit **`minHeight`** (e.g. highlight note field **140pt**), not raw editor geometry alone.

#### Form editor sheet

User edits fields; explicit **Save** in body. Reference: **`HighlightNoteEditSheet`**, **`TagEditSheet`**.

- **`NavigationStack`**, inline title, **`AppPalette.background`** on scroll content.
- Toolbar: **`FlatToolbarTextItem`** **Close**, `.cancellationAction`, accent — no duplicate Cancel/Save in toolbar.
- Body: **always `ScrollView` → bounded `VStack(spacing: 16)`** → **`AppSpacing.screenHorizontal`** + 16pt vertical (same shell for Tag and Highlight).
- Optional read-only context block above field (highlight quote row).
- Input: **`surfaceNested`** well, 12pt continuous radius, 10pt pad — not `.roundedBorder`.
- Validation → `.caption` + `textSecondary`; errors → `.caption` + red.
- Actions (vertical, full width, `.buttonStyle(.plain)`): **Save** accent capsule; optional **Delete …** `surfaceNested` capsule (edit mode).
- Anti-patterns: HStack `.bordered` / `.borderedProminent`; 16pt generic padding instead of **`screenHorizontal`**.

#### List picker sheet

User picks from list or creates via row. Reference: **`CategoryPicker`**, **`RelatedItemsSheet`**.

- **`FlatToolbarTextItem`** **Cancel** (dismiss-only or pass-through via `toolbarCancelPassesSelection`) or **Done** (read-only browse).
- **Unified shell** (above): **`ScrollView` → `LazyVStack` or `VStack`** with section header **`Text`** (`.headline`); row **`Button`s** with **`textPrimary`**; optional **`AppPalette.hairline`** between dense rows (**`CategoryPicker`**).
- **Create and use** accent label for inline create (**`CategoryPicker`**).

#### Read-only diagnostic sheet

Non-editable content + one utility action. Reference: Settings **`importErrorDetailsSheet`**.

- **`FlatToolbarTextItem`** **Done**, accent.
- **Unified shell** (above): **`ScrollView` → `VStack`** with **`screenHorizontal`** + 16pt vertical; monospaced read-only text with **`.textSelection(.enabled)`**.
- Single full-width accent capsule for utility action (e.g. **Copy details to clipboard**). No input well.

---

## 7. Shared components (implement once)

| Component | Spec source | Used on |
|-----------|-------------|---------|
| **`EditorialScreenTitle`** | §3.1, §3.8–§3.10 | Library, Notebook, Save, Chat, Settings |
| **`HairlineHighlightRow`** | §3.6 + §3.8 | Detail, Notebook |
| **`HairlineCapsuleButton`** | §5.1 | Detail bottom actions, failed Retry |
| **`FlatToolbarTextButton`** / **`FlatToolbarTextItem`** | §5.1 / §6 | Sheet toolbars — Close, Cancel, Done, Delete All |
| **`HighlightNoteEditSheet`** | §6.1 | Detail, Notebook — form editor reference |
| **`TagEditSheet`** | §6.1 | Detail — tag add/edit form editor |
| **`CategoryPicker`** | §6.1 | Detail category, Library swipe/bulk file — list picker reference |
| **`RelatedItemsSheet`** | §6.1 | Detail tag tap — list picker |
| **`phathomSheetHeightMeasurable()`** | §6.1 | On inner measure stack — reports height preference |
| **`phathomSheetPresentation()`** | §6.1 | On sheet-root **`NavigationStack`** — measured `.height` + `.large` detents |
| **`phathomToolbarTextLabel`** / **`phathomCapsuleCTALabel`** | §5.1 | Shared `Text` sizing — no CTA truncation |
| **`GalleryListRow`** | §3.4 | Library |
| **`NotebookItemGroupHeader`** | §3.8 | Notebook |
| **`PinnedLibrarySearchBar`** | §3.2 | Library overlay (Cancel + keyboard dismiss) |
| **`LibraryPipelineControlButton`** | §3.2.1 | Library actions row (pause/play) |
| **`SettingsGroupedSurface`** | §3.10 | Settings (style only — preserve disclosure logic) |
| **`ZoneSectionHeader`** | 17pt + 15pt subtitle | Detail AI zone, Settings |
| **`DetailPushNavBar`** | Mock **`.detail-nav`**: **22pt** horizontal inset via **`.safeAreaInset(edge: .top)`** (chevron aligns with scroll content); **4pt** top / **8pt** bottom; **`.toolbar(.hidden, for: .navigationBar)`** on push host | Detail, Settings |
| **`DetailBackBarButton`** / **`DetailShareBarButton`** | Flat chevron (accent) / share (secondary) — **no** glass; mock vertical **8pt** pad on chevron, **8pt** on share | Inside **`DetailPushNavBar`** |
| **`DetailBackBarToolbarItem`** / **`DetailShareToolbarItem`** | Legacy toolbar slots — prefer **`DetailPushNavBar`** for 22pt alignment | — |

---

## 8. Surface index (details in hand-off)

| Surface | Hand-off | Mock | Primary token deltas vs shipped |
|---------|----------|------|--------------------------------|
| **Library** | §3 | `library-ad-search-b-toolbar.html` | 22px inset; gallery hairlines; Search B overlay; editorial title; pipeline in actions row |
| **Detail** | §3.6 | `detail-ad-full-hairline-a.html` | 22px inset; hairline sections; AI zone Option 5; header = host · title · timestamp (**no** source-preview snippet) |
| **Add New** | §3.7 | `add-new-ad-filled-card-a.html` | 22px inset; capsule Save; drop hints/subtitle |
| **Notebook** | §3.8 | `notebook-ad-hairline-feed-a.html` | Unified scroll; shared highlight row; inter-group hairline |
| **Chat** | §3.9 | `chat-ad-placeholder-a.html` | Editorial + two-tier empty copy |
| **Settings** | §3.10 | `settings-ad-grouped-a.html` | 22px inset; editorial title; demoted zone headers; back-only |

---

## 9. Resolve at implementation (rollup)

Items called out across §3 — **Library rows locked May 2026** during implementation planning; remainder decide in phased plan:

| Item | Surfaces | Decision / status |
|------|----------|-------------------|
| **Library `Phathom` principal** | Library | **Locked — drop** on Library tab; Detail push **no** center wordmark |
| **Search dismiss beyond Cancel** | Library | **Locked — Cancel** exits; keyboard dismiss only; no tap-outside |
| **Pipeline control placement** | Library | **Locked — actions row** trailing, before Search (§3.2.1) |
| **Processing badge on Detail** | Detail | Preserve shipped placement |
| **`DetailAIAnalysisDivider` → zone header** | Detail | **Done (Phase 4a)** — `ZoneSectionHeader` Option 5 |
| **`HighlightCardView` refactor** | Detail, Notebook | **Done (Phases 3b + 4a)** — `HairlineHighlightRow` |
| **Drop duplicate nav titles** | Notebook, Chat, Settings | Editorial title owns name |
| **`ContentCardRow` → gallery** | Library | Preserve swipe, bulk, a11y |

---

## 10. Swift translation notes

| Do | Don't |
|----|--------|
| Centralize **`screenHorizontal = 22`** (extend existing spacing helpers or new `AppSpacing` enum) | Port HTML class names or Geist |
| Use `AppPalette` + optional `hairline` Color | Copy `backdrop-filter` literally |
| Idiomatic SwiftUI: `.safeAreaInset`, overlays, `DisclosureGroup`, `NavigationStack` | Side-by-side mock layout in app |
| Preserve shipped behavior unless hand-off explicitly changes UX | Mock lorem as product strings |
| Verify per [`.cursor/rules/simulator-verify.mdc`](../../.cursor/rules/simulator-verify.mdc) | Parallel Llama / RAG scope |
| Use **`Capsule()`** for button shapes per §5.1 | Overlay hairline strokes on system `Picker.segmented` / `UISegmentedControl` |
| Apply **`.sharedBackgroundVisibility(.hidden)`** on every custom **`NavigationStack` `.toolbar`** text/icon item (`FlatToolbarTextItem`) | Raw `ToolbarItem { Button("Cancel") }` without hidden shared background on iOS 26 |
| Size toolbar / CTA labels so the full string is visible (`phathomToolbarTextLabel` / `phathomCapsuleCTALabel`) | `.truncationMode(.tail)` or single-line truncation on button labels |

**Suggested first code investments (planning input — not execution order):**

1. Spacing + hairline semantic on `AppPalette` / layout constants  
2. `HairlineHighlightRow` (Detail + Notebook)  
3. `GalleryListRow` / `ContentCardRow` refactor  
4. `EditorialScreenTitle` + tab-root scroll structure  
5. Surface-by-surface UI swaps per approved phase  

---

## 11. Related documents

| Doc | Relationship |
|-----|--------------|
| [`archive/library-ui-evolution.md`](archive/library-ui-evolution.md) | Discovery authority — locked §3 tables |
| [`archive/ui-evolution-implementation-plan.md`](archive/ui-evolution-implementation-plan.md) | **Shipped** Phases 0–4b — [§15 rollout complete](archive/ui-evolution-implementation-plan.md#15-cold-start--rollout-complete) |
| [`decisions.md`](decisions.md) | Append product commitments when phases ship |
| [`archive/design-mocks/README.md`](archive/design-mocks/README.md) | Mock inventory & CSS conventions |
