# UI Evolution — Cross-Surface Token Sheet

> **Role:** Consolidated **spacing, type, palette, and material** reference distilled from locked discovery ([`library-ui-evolution.md`](library-ui-evolution.md) §3–§3.10 + §4). **Input** to a multi-phased implementation plan — **not** a build spec and **not** a substitute for surface-level locked tables.
>
> **Status:** Complete (May 2026). Discovery HTML locked; Safari review done.
>
> **Use with:** Canonical mocks in [`.design-mocks/`](../../.design-mocks/) · shipped code in **`Phathom/`** · [`AppPalette.swift`](../../Phathom/Phathom/Helpers/AppPalette.swift)

---

## 1. Authority & scope

| Layer | Purpose |
|-------|---------|
| **[`library-ui-evolution.md`](library-ui-evolution.md)** | Locked per-surface decisions, behavior, mocks, rejections |
| **This doc** | Cross-surface tokens + chrome/material matrix + shared components |
| **Implementation plan** | [`ui-evolution-implementation-plan.md`](ui-evolution-implementation-plan.md) — **approved**; cold start → Phase 0 |
| **`Phathom/` code** | Shipped behavior until implementation lands |

**Do not** implement surface-by-surface by copying §3 prose into Swift. Plan phases first (shared tokens → shared rows → tab roots → pushed surfaces).

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
| **Tag chip bg** | `#0B0A0A` | `tagChipBackground` — Detail tags (shipped) |
| **Hairline** | `rgba(255,252,242,0.12)` | Row/section dividers — **add semantic if repeated** (e.g. `AppPalette.hairline`) |
| **Success / warning** | System green / orange | Model status icons, missing-file copy (Settings) — keep system semantic colors |

---

## 3. Spacing & layout rhythm

| Token | Value | Use |
|-------|-------|-----|
| **`screenHorizontal`** | **22pt** | Default content inset — tab roots, Detail, Add New, Notebook, Chat, Settings (up from shipped 16pt where noted) |
| **`sectionVerticalGap`** | **24pt** | Between major section groups (Settings zones, Add New stack) |
| **`editorialTitleBottom`** | **~28pt** | Margin below screen-owned large title before first section |
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
| **Detail actions** | None | Hairline-bordered buttons | Detail bottom |
| **Tag chips** | `#401F12` or shipped tag bg | No enclosing card | Detail |

**Highlight row (shared):** 4px left paprika bar · italic quote · uppercase **Note** when present · one component for Detail + Notebook.

---

## 6. Chrome patterns

| Context | Nav | Screen title | Tab bar | Scroll |
|---------|-----|--------------|---------|--------|
| **Tab root** (Library, Notebook, Chat, Add New) | Drop duplicate `navigationTitle`; Library: **no `Phathom` principal** — actions row only | Editorial **large title in scroll** | Liquid glass §3.5 | Unified — title scrolls with content |
| **Detail push** | Back · **Phathom** center · share | None (article content) | Hidden | Content scroll |
| **Settings push** | **Back only** (Detail back styling) | Editorial **Settings** in scroll | Hidden | Unified; back fixed above scroll |
| **Library at rest** | Select · Pipeline · Search · Settings | **Library** editorial | Visible | Unified |
| **Library search active** | Pinned search over actions band (pipeline hidden) | Same | Visible | Content scrolls under pinned bar |

**Tab bar (preserved):** Library · Notebook · Chat · Add new — do not redesign.

---

## 7. Shared components (implement once)

| Component | Spec source | Used on |
|-----------|-------------|---------|
| **`EditorialScreenTitle`** | §3.1, §3.8–§3.10 | Library, Notebook, Save, Chat, Settings |
| **`HairlineHighlightRow`** | §3.6 + §3.8 | Detail, Notebook |
| **`GalleryListRow`** | §3.4 | Library |
| **`NotebookItemGroupHeader`** | §3.8 | Notebook |
| **`PinnedLibrarySearchBar`** | §3.2 | Library overlay (Cancel + keyboard dismiss) |
| **`LibraryPipelineControlButton`** | §3.2.1 | Library actions row (pause/play) |
| **`SettingsGroupedSurface`** | §3.10 | Settings (style only — preserve disclosure logic) |
| **`ZoneSectionHeader`** | 17pt + 15pt subtitle | Detail AI zone, Settings |
| **Back affordance** | Detail nav back | Detail, Settings |

---

## 8. Surface index (details in hand-off)

| Surface | Hand-off | Mock | Primary token deltas vs shipped |
|---------|----------|------|--------------------------------|
| **Library** | §3 | `library-ad-search-b-toolbar.html` | 22px inset; gallery hairlines; Search B overlay; editorial title; pipeline in actions row |
| **Detail** | §3.6 | `detail-ad-full-hairline-a.html` | 22px inset; hairline sections; AI zone Option 5 |
| **Add New** | §3.7 | `add-new-ad-filled-card-a.html` | 22px inset; capsule Save; drop hints/subtitle |
| **Notebook** | §3.8 | `notebook-ad-hairline-feed-a.html` | Unified scroll; shared highlight row; inter-group hairline |
| **Chat** | §3.9 | `chat-ad-placeholder-a.html` | Editorial + two-tier empty copy |
| **Settings** | §3.10 | `settings-ad-grouped-a.html` | 22px inset; editorial title; demoted zone headers; back-only |

---

## 9. Resolve at implementation (rollup)

Items called out across §3 — **Library rows locked May 2026** during implementation planning; remainder decide in phased plan:

| Item | Surfaces | Decision / status |
|------|----------|-------------------|
| **Library `Phathom` principal** | Library | **Locked — drop** on Library tab; Detail push keeps center **Phathom** |
| **Search dismiss beyond Cancel** | Library | **Locked — Cancel** exits; keyboard dismiss only; no tap-outside |
| **Pipeline control placement** | Library | **Locked — actions row** trailing, before Search (§3.2.1) |
| **Processing badge on Detail** | Detail | Preserve shipped placement |
| **`DetailAIAnalysisDivider` → zone header** | Detail | Replace with Option 5 |
| **`HighlightCardView` refactor** | Detail, Notebook | Single hairline row |
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
| [`library-ui-evolution.md`](library-ui-evolution.md) | Discovery authority — locked §3 tables |
| [`ui-evolution-implementation-plan.md`](ui-evolution-implementation-plan.md) | **Approved** — [Phase 0 cold start §15](ui-evolution-implementation-plan.md#15-cold-start--phase-0) |
| [`docs/decisions.md`](../decisions.md) | Append product commitments when phases ship |
| [`.design-mocks/README.md`](../../.design-mocks/README.md) | Mock inventory & CSS conventions |
