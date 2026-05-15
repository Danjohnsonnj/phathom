# Real markdown highlights — spike spec

**Status (2026-05-15):** Automated spike **passed** (5/5 JS checks in DEBUG harness). Manual menu + parity screenshot optional before sign-off. **No SwiftData / schema work until §10 sign-off.**

Spike gate for [real_markdown_highlights plan](../../.cursor/plans/real_markdown_highlights_e686c5a6.plan.md).

**Normative JS (proven):** [`SourceContentSpikeScript.swift`](../../Phathom/Phathom/Spike/SourceContentSpikeScript.swift) — production `HighlightableMarkdownWebView` SHALL port this file (or extract to `PhathomCore` / bundled resource) with only naming/CSS tweaks.

**Related code:** [`DetailView.swift`](../../Phathom/Phathom/Views/Detail/DetailView.swift), [`BackgroundPipeline.swift`](../../Phathom/Phathom/Services/BackgroundPipeline.swift), [`HTMLMarkdownConverter.swift`](../../Phathom/Phathom/Services/HTMLMarkdownConverter.swift), [`DetailMarkdownTheme.swift`](../../Phathom/Phathom/Helpers/DetailMarkdownTheme.swift), [`HighlightableMarkdownWebView.swift`](../../Phathom/Phathom/Views/Detail/HighlightableMarkdownWebView.swift) (production path).

---

## Purpose

Prove five risky areas **before** `Highlight` / `ContentItem` schema changes:

1. One canonical `sourceMarkdown` string (trim at persist).
2. Selection → UTF-16 `{start, end, text}` across multiple `data-md-*` spans.
3. DOM-safe highlight overlays for stored ranges.
4. Native **Highlight** action on a `WKWebView` surface.
5. Acceptable visual drift vs MarkdownUI (`.phathomNote`).

---

## Locked product decisions (v1)

| Topic | Decision |
|-------|----------|
| Anchor space | UTF-16 offsets into **stored** `sourceMarkdown` (not stripper plain, not HTML text nodes alone). |
| Canonical string | Trim once at ingest; rewrite `item.sourceMarkdown` to trimmed value before indexer. |
| Resize | **Out** — create highlight + tap sheet only; no `onResizeHighlight` on web path. |
| Legacy rows (no HTML) | `Markdown` + `.textSelection`; **no** create. Detail **does** run `ensureSourceContentHTMLIfNeeded()` eagerly on `.onAppear` and `sourceMarkdown` change — legacy items get indexed at view time. |
| Backup | `LibraryBackupService` **v2** required — highlights are exported/imported as `HighlightRecord` arrays per item. v1 files import cleanly (highlights default to `[]`). |
| Existing highlights | Wiped on upgrade when schema lands. |

---

## 1. Canonical `sourceMarkdown`

### Problem today

- `ContentItem.strippedSourceText` trims then strips (`ContentItem.swift`).
- `sourceMarkdownForDisplay` trims for emptiness check but can return **untrimmed** `md` (`DetailView.swift` ~628–631).
- Indexer + `Highlight` must not use two different strings.

### SHALL (normative)

1. SHALL define **canonical markdown** = `sourceMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)` at persist time only.
2. SHALL assign canonical value in pipeline immediately after scrape:

   ```text
   let raw = result.sourceMarkdown
   item.sourceMarkdown = raw.map { t in
       let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
       return trimmed.isEmpty ? nil : trimmed
   } ?? nil
   ```

   Hook: [`BackgroundPipeline`](../../Phathom/Phathom/Services/BackgroundPipeline.swift) ~343, **before** any future `SourceContentIndexer` call (same transaction as today’s assign).

3. SHALL run `SourceContentIndexer` only when canonical `sourceMarkdown` is non-nil/non-empty.
4. SHALL use stored blob for: `data-md-*` offsets, `Highlight.sourceMarkdownOffset/Length`, Detail display (read `item.sourceMarkdown` directly — no second trim in display helper).
5. SHALL keep `MarkdownStripper` / `strippedSourceText` for LLM, search, Spotlight only.

### Validation

- Unit: given `"  # Hi\n\n"` scrape mock → stored `"# Hi"`; UTF-16 length matches stored string.
- Unit: empty / whitespace-only → `nil`, indexer skipped.

---

## 2. `SourceContentIndexer` offset map (design for implementation)

### Output

- `sourceContentHTML`: full document HTML (body fragment + injected CSS class namespace `phathom-source`).
- `sourceContentIndexVersion`: `1` initially; bump when visitor rules change.

### `data-md-*` spans

Each **visible text leaf** in the markdown AST gets a wrapper:

```html
<span data-md-start="42" data-md-end="47">hello</span>
```

- `start` / `end`: UTF-16 code unit indices into **canonical stored** `sourceMarkdown` (Swift `String` UTF-16 view).
- Spans are **half-open** `[start, end)` — same convention as `NSRange` length.
- Offsets point at **source markdown code units** for that leaf’s contribution (including syntax mapping rules below), not rendered HTML character indices.

### Visitor rules (minimum v1)

| Construct | HTML | Offset rule |
|-----------|------|-------------|
| Plain text | `<span data-md-*>` | Direct UTF-16 range in source for that text node. |
| `**bold**` / `*italic*` | `<strong>` / `<em>` with inner spans | Inner visible text only; delimiters excluded from span. |
| `` `code` `` | `<code>` | Inner backtick content only. |
| `[label](url)` | `<a href="…">` | **Label** text range only (not `](url)`). |
| Headings | `<h1>`…`<h6>` | Text after `#` markers per line. |
| List items | `<li>` | Item body text; list markers excluded. |
| Fenced code | `<pre><code>` | Full fence interior (optional: single span for whole block). |
| Blockquote | `<blockquote>` | Inner paragraph spans. |
| Tables | `<table>` | Per-cell text spans (if `HTMLMarkdownConverter` emits tables). |

**Non-goals for indexer v1:** map offsets inside HTML entities, soft line breaks inside paragraphs beyond what swift-markdown exposes.

### Golden tests (PhathomCore)

Fixtures under `PhathomCoreTests/Fixtures/source_markdown/` (to add with indexer):

| Fixture | Assert |
|---------|--------|
| `heading_and_para.md` | Spans cover visible title + body; no `#` inside span text. |
| `bold_link.md` | Bold label + link label ranges disjoint; selection across both merges in JS (§3). |
| `list.md` | List marker not in span text. |
| `code_fence.md` | Fence delimiters not in span. |
| `table.md` | Only if scrape pipeline produces tables. |
| `real_article_snippet.md` | Output of `HTMLMarkdownConverter` on a saved HTML snippet. |

For every span: `0 <= start < end <= markdown.utf16.count` and `markdown.utf16[start..<end]` decodes to visible text matching DOM `textContent` for that span (modulo whitespace normalization policy: **no** extra collapse beyond what visitor emits).

---

## 3. Selection JS (multi-span merge) — proven algorithm

**Source of truth:** [`SourceContentSpikeScript.swift`](../../Phathom/Phathom/Spike/SourceContentSpikeScript.swift) (`phathomExpandSpanHits`, `phathomCollectSpansInRange`, `phathomSelectionPayload`, `phathomPayloadFromSpan`).

### Functions (production user script)

| Function | Role |
|----------|------|
| `phathomExpandSpanHits(initial)` | After `intersectsNode` hits, include every `[data-md-start]` span overlapping `[minStart, maxEnd)`. **Required** — WK under-reports spans on programmatic ranges and inside `<mark>`. |
| `phathomCollectSpansInRange(range)` | `intersectsNode` under `commonAncestorContainer`, then expand. |
| `phathomSelectionPayload()` | User selection → JSON `{ start, end, text }` or `null`. `text` = `selection.toString()`. |
| `phathomPayloadFromSpan(el)` | Attribute read on one span. **Not** for user create — diagnostics only. |

### Merge rule

1. Spans intersecting `getRangeAt(0)` → expand by UTF-16 overlap.
2. `start` = min `data-md-start`; `end` = max `data-md-end`.
3. Native stores `quotedText` from `selection.toString()`.

### WK gotcha: programmatic vs user selection

| Path | Behavior |
|------|----------|
| **User** select / long-press | `phathomSelectionPayload()` reliable. |
| **Programmatic** `selectNodeContents` + immediate read | Often `null` / wrong — especially inside `<mark>`. **Not** used in production. |

### Native bridge

- `WKUserScript` at `atDocumentEnd`.
- `selectionchange` → `WKScriptMessageHandler` `phathomSelection` (JSON string or `null`).
- Cache last non-null payload for `UIEditMenuInteraction` (`menuFor` is synchronous).

### Validation on create (Swift)

- `0 <= start < end <= sourceMarkdown.utf16.count`
- `quotedText` non-empty; trim; best-effort substring of UTF-16 slice

### Edge cases

| Case | Behavior |
|------|----------|
| Selection crosses block boundaries | Single `[start,end)` in markdown space (may include newlines). |
| Partial span | Expand fills gaps between spans in range. |
| Collapsed CSS clip | Selection OK; expand does not change offsets. |

### Automated proof (2026-05-15)

`phathomSpikeSelfTest` in DEBUG harness: `single_bold`, `single_link_label`, `across_bold_and_link`, `across_emphasis_boundary`, `overlay_marks_present` — **all passed**.

---

## 4. Highlight overlay (DOM-safe)

### Rejected

- String splice on `sourceContentHTML` by UTF-16 offset (breaks tags, entities, nested spans).

### Approved: load-time DOM merge (proven)

**v1:** Option B only — after `loadHTMLString` / `didFinish`, call `phathomApplyHighlights(ranges)` once per load.

**Functions:** `phathomWrapMarkdownRange(start, end, id)`, `phathomApplyHighlights(ranges)`, `phathomClearHighlights()` (unwrap marks before re-apply).

**`phathomWrapMarkdownRange` algorithm:**

1. Spans where `[data-md-start, data-md-end)` intersects `[start, end)`.
2. Group by block (`p`, `li`, `h1`–`h4`, `blockquote`, `td`, `pre`).
3. Per group: insert `<mark class="phathom-highlight" data-highlight-id="…">`, move spans inside (DOM `appendChild` — no HTML string splice).
4. Cross-block range → multiple `<mark>` elements, **same** `data-highlight-id`.

**Order:** On Detail load, `phathomClearHighlights()` then apply all stored highlights (avoids nested marks when toggling).

**Tap:** `click` on `.phathom-highlight` → `WKScriptMessageHandler` `phathomHighlightTap` posts highlight UUID string.

### Z-order / CSS

```css
mark.phathom-highlight {
  background: /* AppPalette accent ~20% */;
  border-radius: 2px;
}
```

---

## 5. WK **Highlight** menu (native)

### Context

Today: production uses **`HighlightableMarkdownWebView`** — `UIEditMenuInteraction` + cached selection payload adds **Highlight** (`HighlightableMarkdownWebView.swift`).

### Chosen path: `UIEditMenuInteraction` + cached selection (proven in spike)

1. `UIEditMenuInteraction(delegate:)` on `WKWebView` (iOS 16+).
2. `selectionchange` updates `lastSelectionPayload` via `phathomSelection` message handler (parse JSON → struct).
3. `editMenuInteraction(_:menuFor:suggestedActions:)` appends `UIAction(title: "Highlight")` when `lastSelectionPayload != nil`.
4. Action calls `onCreateHighlight(start, length, quotedText)` — **do not** call JS inside `menuFor` (async; menu is sync).

**Rejected for menu / self-test:**

- `callAsyncJavaScript` with inline JSON args — `arguments` is `[String: Any]` dict keyed by parameter name; return value bridges as native objects, not JSON strings.
- `JSON.parse` on values already passed as JS arrays (throws `Unexpected identifier "object"`).

**Self-test / one-shot JS:** use `evaluateJavaScript` with `return JSON.stringify(...)` and parse `String` on Swift side. See `SourceContentSpikeWebView.runSelfTest`.

**Fallback (if menu insufficient):** anchor `UIMenu` to `getBoundingClientRect()` from JS — not needed in spike.

### Manual proof checklist (optional before sign-off)

- [ ] Long-press or select → system edit menu appears.
- [ ] **Highlight** visible when selection non-empty.
- [ ] Action creates highlight with plausible offsets in Log.

### Not in v1

- `onResizeHighlight`, drag handles, `window.getSelection()` resize.

---

## 6. MarkdownUI parity gate

### Goal

Source section on web items should feel like **main** (`Markdown` + `.phathomNote`), not a second theme.

### Method

1. Add fixture `parity_sample.md` (heading, paragraph, bold, link, list, blockquote, inline code, fenced code, table if supported).
2. Render A: SwiftUI preview / test host with `Markdown(fixture).markdownTheme(.phathomNote)`.
3. Render B: `SourceContentIndexer` HTML in spike WK page with CSS ported from [`DetailMarkdownTheme.swift`](../../Phathom/Phathom/Helpers/DetailMarkdownTheme.swift) (GitHub base, 16pt body, heading dividers h1/h2, nested code block background, table borders).
4. Side-by-side screenshot (iPhone 16 Pro sim, light + dark).

### Allowed drift (document, don’t block v1 unless severe)

| Element | Allowed |
|---------|---------|
| Heading underline | CSS `border-bottom` vs SwiftUI `Divider` — OK if spacing ±4pt |
| List bullets / numbers | Minor indent / glyph differences |
| Tables | Simplified borders OK if readable |
| Line height | Dynamic Type must track; `-webkit-text-size-adjust: 100%` |

### Block ship if

- Wrong heading level styling (h1 vs body indistinguishable).
- Links not accent-colored / not tappable.
- Code blocks unreadable (no background / wrong font).
- Collapsed clip height wildly different from main (~8 body lines).

### CSS port checklist (minimum)

- Body: system font 16pt, `AppPalette` text colors via CSS variables injected from native hex.
- `h1`/`h2`: semibold scale + bottom rule.
- `a`: accent color.
- `pre` / `code`: monospaced 0.85em, nested surface background.
- `blockquote`: left bar + secondary text.
- Collapsed: `.phathom-source-collapsed { max-height: …; overflow: hidden; }` using `em` from body line-height × 8.

---

## 7. Storage budget

| Field | Note |
|-------|------|
| `sourceMarkdown` | Already capped ~50 KB UTF-8 at [`HTMLMarkdownConverter`](../../Phathom/Phathom/Services/HTMLMarkdownConverter.swift). |
| `sourceContentHTML` | Expect ~1.2–2.5× markdown size (tags + spans). Monitor; no compression v1. |

---

## Spike execution checklist

| # | Task | Owner | Done |
|---|------|-------|------|
| 1 | Throwaway `WKWebView` host page + fixture HTML with fake `data-md-*` | Dev | ☑ |
| 2 | Implement + log `phathomSelectionPayload()` cases (§3) | Dev | ☑ |
| 3 | Implement `phathomApplyHighlights` on sample ranges (§4) | Dev | ☑ |
| 4 | Prove **Highlight** menu path (§5) on device/sim | Dev | ☐ optional manual |
| 5 | Parity screenshot A vs B (§6) | Dev | ☐ optional manual |
| 6 | Sign off this doc (§10) | User | ☐ |

**Gate:** §10 sign-off → `schema-highlight-wipe`. Rows 4–5 recommended but not blocking if automated 5/5 passed and parity visually OK in harness.

### Spike harness (2026-05-15)

**DEBUG only** — Settings → Developer → **Source content spike (WK)**.

| Component | Path |
|-----------|------|
| Fixtures + HTML | `Phathom/Phathom/Spike/SourceContentSpikeFixtures.swift` |
| JS bridge | `Phathom/Phathom/Spike/SourceContentSpikeScript.swift` |
| WK host | `Phathom/Phathom/Spike/SourceContentSpikeWebView.swift` |
| Screen | `Phathom/Phathom/Spike/SourceContentSpikeView.swift` |
| UTF-16 unit tests | `PhathomCoreTests/SourceContentSpikeFixturesTests.swift` |

**Automated:** **Run phathomSpikeSelfTest** → expect **All 5 JS checks passed** (clears overlays first; disables sample overlay toggle for clean DOM).

**Manual (optional):** §5 menu checklist; parity A vs B in same screen.

### Spike decisions recorded (implementation normative)

| Area | Decision |
|------|----------|
| Canonical markdown | Store trimmed at ingest (§1). Fix `sourceMarkdownForDisplay` to use stored blob only. |
| Selection | `phathomExpandSpanHits` + `phathomSelectionPayload`; `selectionchange` cache. |
| Overlay | `phathomWrapMarkdownRange` / `phathomClearHighlights` (§4). |
| Native menu | `UIEditMenuInteraction` + cached payload (§5). **Not** `callAsyncJavaScript` for menu. |
| JS bridge tests | `evaluateJavaScript` + `JSON.stringify` return; parse `String` in Swift. |
| Parity | Port `SourceContentSpikeFixtures.sourceContentCSS`; drift table §6. |
| DEBUG harness | Keep until production web view ships; then delete or slim to regression. |

---

## 8. Native ↔ JS bridge (pitfalls — do not repeat)

| Pattern | Use | Avoid |
|---------|-----|-------|
| User selection → native | `selectionchange` + `phathomSelectionPayload()` message | Reading selection only in `menuFor` without cache |
| One-shot test / batch JS | `evaluateJavaScript("(function(){ return JSON.stringify(...); })()")` | `callAsyncJavaScript("fn", arguments: [array])` then `JSON.parse` on result |
| `callAsyncJavaScript` args | `["paramName": value]` dictionary | `[value]` array (type error); passing array to `JSON.parse` inside JS |
| Return to Swift | Prefer JSON **string** from JS; parse in Swift | Assuming return is `[[String:Any]]` (often `Optional<Any>` / `NSArray`) |
| Apply highlights after load | `webView(_:didFinish:)` + `callAsyncJavaScript("phathomApplyHighlights", arguments: ["ranges": …])` OR embed in `evaluateJavaScript` | String splice on `sourceContentHTML` |

Simulator console noise (`Failed to resolve host network app id`, `Unable to hide query parameters`) — **benign**; ignore.

---

## 9. Blast radius — all files referencing old Highlight API

A fresh agent must update or remove **every** consumer below when the schema changes. Grep `plainTextOffset|plainTextLength|markdownStripperVersion|highlightsSortedByPlainTextOffset` to verify none remain.

### Code to update

| File | What references old API | Fix |
|------|------------------------|-----|
| `PhathomCore/Highlight.swift` | `plainTextOffset`, `plainTextLength`, `markdownStripperVersion`, `init(plainTextOffset:…)` | Replace with `sourceMarkdownOffset`, `sourceMarkdownLength`; drop `markdownStripperVersion`. New `init(sourceMarkdownOffset:sourceMarkdownLength:quotedText:userNote:)`. |
| `PhathomCore/ContentItem.swift` | `highlightsSortedByPlainTextOffset` computed property | Rename → `highlightsSortedByOffset`; sort by `sourceMarkdownOffset`. |
| `DetailView.swift` ~107, ~706 | Calls `item.highlightsSortedByPlainTextOffset` | Update call sites to renamed property. |
| `DetailView.swift` ~641–660 | `createHighlightFromSelection` uses `strippedSourceText` / plain offsets; `resizeHighlightModel` uses `plainTextOffset` | Rewrite `createHighlightFromSelection` with `sourceMarkdownOffset`/`Length`; remove `resizeHighlightModel`. |
| `DetailView.swift` ~628–631 | `sourceMarkdownForDisplay` returns untrimmed `md` | Return `item.sourceMarkdown` directly (already trimmed at ingest). |
| `DetailView.swift` ~664–675 | `markdownBuiltForSource` + `MarkdownPlainDecoration` | Remove — replaced by web view. |
| `BackgroundPipeline.swift` ~623 | `item.highlightsSortedByPlainTextOffset` in tag prompt builder | Update to renamed property. |
| `HighlightsNotesSection.swift` ~4 | Docstring references `plainTextOffset` sort | Update docstring. |
| `HighlightableSourceTextView.swift` (removed) | Entire file — legacy UITextView experiment | **Deleted** — production uses `HighlightableMarkdownWebView`. |
| `StoreMigrationSmokeTests.swift` ~31 | `Highlight(plainTextOffset: 0, plainTextLength: 1, quotedText: "x")` | Update init to new params; update test name for V3→V4 if schema version bumps. |
| `MarkdownStripper.swift` ~5 | `algorithmVersion` docstring references `Highlight.markdownStripperVersion` | Remove cross-reference (field deleted). Keep `algorithmVersion` for `strippedSourceText` only. |

### Code to delete (spike cleanup)

| File | Why delete |
|------|-----------|
| `Phathom/Phathom/Spike/SourceContentSpikeScript.swift` | JS extracted to production `HighlightableMarkdownWebView`; spike harness no longer needed. |
| `Phathom/Phathom/Spike/SourceContentSpikeFixtures.swift` | Hand-built HTML replaced by `SourceContentIndexer` output. |
| `Phathom/Phathom/Spike/SourceContentSpikeWebView.swift` | Replaced by `HighlightableMarkdownWebView`. |
| `Phathom/Phathom/Spike/SourceContentSpikeView.swift` | DEBUG screen replaced by production path. |
| `SettingsTab.swift` `developerSection` | `#if DEBUG` section linking to spike view; remove entire computed property + `Form` reference. |
| `PhathomCoreTests/SourceContentSpikeFixturesTests.swift` | Offset invariants superseded by `SourceContentIndexer` golden tests. |

### Code to keep (not affected)

| File | Reason |
|------|--------|
| `MarkdownStripper.swift` | Still used for LLM / search / Spotlight via `strippedSourceText`. |
| `MarkdownPlainDecoration.swift` | Keep for reference; not imported by production path after web view ships. |
| `HighlightsNotesSection.swift` | Logic unchanged; just fix docstring + sort property name. |
| `HighlightNoteEditSheet` (in `DetailView.swift`) | Unchanged; still receives `Highlight` with `quotedText` + `userNote`. |

---

## 10. Sign-off

| Check | Status |
|-------|--------|
| Automated `phathomSpikeSelfTest` 5/5 | ☑ (2026-05-15) |
| §1 canonical trim SHALL documented | ☑ |
| §3–§5 algorithms match `SourceContentSpikeScript.swift` | ☑ |
| Manual Highlight menu (§5) | ☐ user |
| Parity acceptable (§6) | ☐ user |
| **Approved for schema work** | ☐ user initial below |

**Sign-off:** _____________________ **Date:** ___________

---

## After spike (implementation order)

1. Schema + highlight wipe + `sourceContentHTML` fields.
2. `SourceContentIndexer` + golden tests + pipeline hook (trim then index).
3. `HighlightableMarkdownWebView` — port `SourceContentSpikeScript` + spike CSS → production theme.
4. Detail wire-up; ~~remove `HighlightableSourceTextView`~~ **done** — `HighlightableMarkdownWebView` is production.
5. `docs/decisions.md` + supersede 2026-05-14 rows.

---

## Out of scope (unchanged)

- Markdown in user notes.
- Web highlight resize.
