# Phathom — Domain Glossary

Canonical **names** for domain concepts. **Rationale and invariants** live in [`docs/decisions.md`](docs/decisions.md) — that file wins on conflict.

Use these terms exactly in issue titles, PRDs, refactor proposals, and test names. Do not invent synonyms.

---

## Core entities

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **ContentItem** | SwiftData `@Model` for one library capture (web, note, or media). | [`ContentItem.swift`](Phathom/PhathomCore/Sources/PhathomCore/ContentItem.swift) · [decisions index](docs/decisions.md#active-invariants-index) |
| **Category** | Optional structural `@Model Category` on `ContentItem` (relational, not a tag). | [`Category.swift`](Phathom/PhathomCore/Sources/PhathomCore/Category.swift) · [2026-05-16](docs/decisions.md#decision-log) |
| **Tag** | User/LLM subject labels; stored lowercase ASCII kebab-case via **`TagNameNormalizer`**. | [2026-05-02 Tag format](docs/decisions.md#decision-log) |
| **Highlight** | User annotation anchored by UTF-16 offset into stored **`sourceMarkdown`**. | [2026-05-15 Highlight anchors](docs/decisions.md#decision-log) |
| **Extracts** | Label/value pairs from LLM analysis (generalized “key figures”). | [Pre Extracts decision](docs/decisions.md#decision-log) |

---

## Content kinds & status

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **ContentKind** | Capture type: `web`, `media`, or `note`. | [`Enums.swift`](Phathom/PhathomCore/Sources/PhathomCore/Enums.swift) |
| **ProcessingStatus** | Pipeline state: `pending` → scrape/embed → summarize/tag/extract → `completed` or `failed`. | [`Enums.swift`](Phathom/PhathomCore/Sources/PhathomCore/Enums.swift) · [granular sub-states](docs/decisions.md#decision-log) |
| **ReadStatus** | User triage on library rows: `new`, `read`, or `filed` (distinct from **`ProcessingStatus`**). Orthogonal to **Focus Stack** — `filed` = on the shelf, not cognitive closure. | [`Enums.swift`](Phathom/PhathomCore/Sources/PhathomCore/Enums.swift) · [2026-05-08](docs/decisions.md#decision-log) |
| **ProcessingStatusPresentation** | Maps **`ProcessingStatus`** (+ optional **`processingDetail`**) to user-facing chip copy. | [2026-05-02 status labels](docs/decisions.md#decision-log) |

---

## Focus Stack (shipped v1)

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **Focus Stack** | Capped workbench (**max 7**) of articles user explicitly committed to engage with *now*; **Focus tab** surface (warehouse = Library). Tab bar: **Library · Notebook · Focus · Add New**. | [`FocusTab.swift`](Phathom/Phathom/Views/Focus/FocusTab.swift) · [`focus-stack.md`](docs/handoff/focus-stack.md) · [2026-06-09](docs/decisions.md#decision-log) |
| **Focus commitment** | Active membership of a **`ContentItem`** in **Focus Stack** (`FocusEntry`); distinct from **`ReadStatus`**. | [`FocusEntry.swift`](Phathom/PhathomCore/Sources/PhathomCore/FocusEntry.swift) |
| **Focus outcome** | Resolution when leaving Focus: **Reference** · **Takeaway** · **Revisit** · **Release** (+ **Connect** v2); stored in append-only **`FocusOutcome`** log. | [`FocusOutcome.swift`](Phathom/PhathomCore/Sources/PhathomCore/FocusOutcome.swift) |
| **FocusEntry** | Active Focus membership — `addedAt`, `sortOrder`, `lastTouchedAt` (engagement **since add** only; **re-add resets**). Max **7** rows globally. | [`FocusEntry.swift`](Phathom/PhathomCore/Sources/PhathomCore/FocusEntry.swift) |
| **FocusOutcome** | Append-only closure log — `outcomeKind`, `takeawayText`, `linkedHighlightID`, `scheduledResurfaceAt` (Revisit). | [`FocusOutcome.swift`](Phathom/PhathomCore/Sources/PhathomCore/FocusOutcome.swift) |
| **Due for revisit** | Item left Focus via **Revisit** with `scheduledResurfaceAt` ≤ now; **Library trailing clock icon** only (user re-adds manually). | [`FocusStackService.dueForRevisit`](Phathom/PhathomCore/Sources/PhathomCore/FocusStackService.swift) |
| **Focus row** | Detail hairline row for add/remove Focus — label **Focus** + **Toggle** (Category parity); primary entry point. | [`DetailView.swift`](Phathom/Phathom/Views/Detail/DetailView.swift) |
| **Focus closure indicator** | Detail read-only subline under Focus row when **not** in Focus — latest **`FocusOutcome`** by `completedAt`. No processed-focus gallery v1. | [`DetailView.swift`](Phathom/Phathom/Views/Detail/DetailView.swift) |
| **Stale nudge** | Focus tab banner at ≥7d untouched — Keep / Complete / Remove. Pairs with progressive row tint. | [`FocusStaleNudgeSheet.swift`](Phathom/Phathom/Views/Focus/FocusStaleNudgeSheet.swift) |
| **Thread** | v2 **Connect** container — named ongoing inquiry linking member articles, highlights, takeaways. | [`focus-stack.md`](docs/handoff/focus-stack.md) · [`ChatThread.swift`](Phathom/PhathomCore/Sources/PhathomCore/ChatThread.swift) (evolution TBD) |

---

## Capture & source text

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **rawText** | Flattened plain text for LLM and in-app library search (not indexed into Spotlight). | [sourceMarkdown decision](docs/decisions.md#decision-log) · [library search](docs/concepts/library-search.md) |
| **sourceMarkdown** | Optional Markdown from generic web scrape; Detail Source Content; ~50 KB cap. | [2026-05-02 sourceMarkdown](docs/decisions.md#decision-log) |
| **sourceContentHTML** | Themed HTML with span anchors for WKWebView highlight selection. | [2026-05-15 Source Content](docs/decisions.md#decision-log) |
| **MainContentExtractor** | Readability-style main-content picker for generic web **`rawText`** + **`sourceMarkdown`**. | [2026-05-02 Readability](docs/decisions.md#decision-log) |
| **titleUserSet** | When true, scrape pipeline must not overwrite user-edited **`title`**. | [2026-05-03](docs/decisions.md#decision-log) |

---

## Inference & pipeline

Concept stubs (**links only** — see [`docs/concepts/inference/index.md`](docs/concepts/inference/index.md)):

- [**withSession**](docs/concepts/inference/with-session.md) · [**BackgroundPipeline**](docs/concepts/inference/background-pipeline.md) · [**SharedLlamaInference**](docs/concepts/inference/shared-llama-inference.md) · [**KV cache reuse**](docs/concepts/inference/kv-cache-reuse.md) · [**GGUF bookmark**](docs/concepts/inference/gguf-bookmark.md) · [**PipelineUserPause**](docs/concepts/inference/pipeline-user-pause.md) · [**VisionContentAnalyzer**](docs/concepts/inference/vision-content-analyzer.md)

---

## Library & UI services

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **LibrarySearchService** | In-app library search bucketing (Stage 1 match + tag adjacency; Stage 2 Dive deeper). | [`library-search.md`](docs/concepts/library-search.md) · [`LibrarySearchService.swift`](Phathom/Phathom/Services/LibrarySearchService.swift) |
| **filterCategory** | Category filter in library (All / Uncategorized / structural **`Category`**). | [decisions index](docs/decisions.md#active-invariants-index) |
| **Archive** | Soft-delete: **`isArchived`** + **`archivedAt`**; 48h retention; Spotlight de-index. | [Archive decision](docs/decisions.md#decision-log) |
| **phathomDidArchiveItem** | Notification for archive undo; batch payload **`itemIDs`** (`[String]` UUIDs). | [2026-05-12 bulk archive](docs/decisions.md#decision-log) |
| **LibraryBackupService** | JSON export/import envelope (current **`formatVersion` 4**; includes **`focusEntry`** + **`focusOutcomes[]`**). | [2026-06-09 backup v4](docs/decisions.md#decision-log) |
| **TagRelationService** | Tag adjacency + semantic expansion for related items (primary GGUF only). | [2026-05-22 TagRelation](docs/decisions.md#decision-log) |
| **MediaDisplayImageLoader** | Detail media hero + View Photo: cache → coalesced fault/decode per item UUID. | [2026-06-01 Detail media](docs/decisions.md#decision-log) |
| **normalizedJPEGForLibraryStorage** | On-disk `thumbnailData` for new captures: max **1024px** side, **0.72** JPEG quality. | [2026-06-01 Detail media](docs/decisions.md#decision-log) |
| **MediaImageLoadMetrics** | Opt-in device timing (`-MediaImageProfiling`); subsystem `com.phathom.media`. | [2026-06-01 Detail media](docs/decisions.md#decision-log) |

---

## Explicit non-goals (v1)

| Term | Meaning |
|------|---------|
| **CloudKit / sync** | Local-only forever — no cloud sync. |
| **Embedding persistence** | Phase 2: **`embedding`** is pipeline state only; RAG vectors deferred (see [`phase-3-rag-chat.md`](docs/handoff/phase-3-rag-chat.md)). |
| **Standalone Chat / RAG tab** | **Removed** — Focus tab replaced Chat placeholder; open RAG **deferred**; may re-scope to thread-scoped assist. |
| **Apple FoundationModels** | Not used; **Llama.cpp** is sole AI engine. |

---

## Gaps

If a concept you need is missing here, check **`docs/decisions.md`** and Swift sources before coining a new term. Note gaps in issues/PRDs rather than inventing vocabulary.
