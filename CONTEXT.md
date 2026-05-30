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
| **ReadStatus** | User triage on library rows: `new`, `read`, or `filed` (distinct from **`ProcessingStatus`**). | [`Enums.swift`](Phathom/PhathomCore/Sources/PhathomCore/Enums.swift) · [2026-05-08](docs/decisions.md#decision-log) |
| **ProcessingStatusPresentation** | Maps **`ProcessingStatus`** (+ optional **`processingDetail`**) to user-facing chip copy. | [2026-05-02 status labels](docs/decisions.md#decision-log) |

---

## Capture & source text

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **rawText** | Flattened plain text for LLM, library search, and Spotlight. | [sourceMarkdown decision](docs/decisions.md#decision-log) |
| **sourceMarkdown** | Optional Markdown from generic web scrape; Detail Source Content; ~50 KB cap. | [2026-05-02 sourceMarkdown](docs/decisions.md#decision-log) |
| **sourceContentHTML** | Themed HTML with span anchors for WKWebView highlight selection. | [2026-05-15 Source Content](docs/decisions.md#decision-log) |
| **MainContentExtractor** | Readability-style main-content picker for generic web **`rawText`** + **`sourceMarkdown`**. | [2026-05-02 Readability](docs/decisions.md#decision-log) |
| **titleUserSet** | When true, scrape pipeline must not overwrite user-edited **`title`**. | [2026-05-03](docs/decisions.md#decision-log) |

---

## Inference & pipeline

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **withSession** | Serialized GGUF access via **`SharedLlamaInference`** + **`AsyncLock`**; no parallel Llama calls. | [2026-05-02 serialized session](docs/decisions.md#decision-log) |
| **BackgroundPipeline** | Orchestrates scrape → embed → analyze (summarize, tags, extracts) and media vision path. | [`BackgroundPipeline.swift`](Phathom/Phathom/Services/BackgroundPipeline.swift) |
| **SharedLlamaInference** | Single shared Llama session; primary vs optional tagging GGUF bookmarks. | [2026-05-15 tagging GGUF](docs/decisions.md#decision-log) |
| **KV cache reuse** | Article prefix decoded once; per-task seq fork via **`llama_memory_seq_cp`**. | [2026-05-03 KV reuse](docs/decisions.md#decision-log) |
| **GGUF bookmark** | Security-scoped bookmark to user-selected model file (not copied into app sandbox). | [2026-05-02 bookmark](docs/decisions.md#decision-log) |
| **PipelineUserPause** | Global user pause flag; gates **`schedule*`** and foreground/BG processing. | [2026-05-27 Library Pause](docs/decisions.md#decision-log) |
| **VisionContentAnalyzer** | VLM path for media via llama.cpp **`libmtmd`** (text GGUF + mmproj). | [2026-05-24 media vision](docs/decisions.md#decision-log) |

---

## Library & UI services

| Term | One-line definition | Anchor |
|------|---------------------|--------|
| **LibrarySearchService** | Filters library by kind, **`ReadStatus`**, category, and search query. | [`LibrarySearchService.swift`](Phathom/Phathom/Services/LibrarySearchService.swift) |
| **filterCategory** | Category filter in library (All / Uncategorized / structural **`Category`**). | [decisions index](docs/decisions.md#active-invariants-index) |
| **Archive** | Soft-delete: **`isArchived`** + **`archivedAt`**; 48h retention; Spotlight de-index. | [Archive decision](docs/decisions.md#decision-log) |
| **phathomDidArchiveItem** | Notification for archive undo; batch payload **`itemIDs`** (`[String]` UUIDs). | [2026-05-12 bulk archive](docs/decisions.md#decision-log) |
| **LibraryBackupService** | JSON export/import envelope (current **`formatVersion` 3**). | [2026-05-08 backup](docs/decisions.md#decision-log) |
| **TagRelationService** | Tag adjacency + semantic expansion for related items (primary GGUF only). | [2026-05-22 TagRelation](docs/decisions.md#decision-log) |

---

## Explicit non-goals (v1)

| Term | Meaning |
|------|---------|
| **CloudKit / sync** | Local-only forever — no cloud sync. |
| **Embedding persistence** | Phase 2: **`embedding`** is pipeline state only; RAG vectors deferred to Phase 3. |
| **Apple FoundationModels** | Not used; **Llama.cpp** is sole AI engine. |

---

## Gaps

If a concept you need is missing here, check **`docs/decisions.md`** and Swift sources before coining a new term. Note gaps in issues/PRDs rather than inventing vocabulary.
