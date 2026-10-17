# Concepts index

Term lookup — **links only**; rationale stays in [`decisions.md`](../decisions.md). Conventions: [`doc-structure.md`](../agents/doc-structure.md).

---

## Core entities

* [ContentItem](content-item.md) — SwiftData capture model
* [Category](category.md) — structural category on ContentItem
* [Tag](tag.md) — kebab-case labels via TagNameNormalizer
* [Highlight](highlight.md) — UTF-16 anchored annotation
* [Extracts](extracts.md) — LLM label/value pairs (“key figures”)

## Content kinds & status

* [ContentKind](content-kind.md) — web, media, or note
* [ProcessingStatus](processing-status.md) — pipeline state enum
* [ReadStatus](read-status.md) — library triage enum
* [ProcessingStatusPresentation](processing-status-presentation.md) — chip copy mapping

## Focus Stack (shipped v1)

* [Focus Stack](focus-stack.md) — capped Focus tab workbench
* [Focus commitment](focus-commitment.md) — active Focus membership
* [Focus outcome](focus-outcome.md) — Reference · Takeaway · Revisit · Release
* [FocusEntry](focus-entry.md) — active membership row
* [FocusOutcome](focus-outcome-log.md) — append-only closure log
* [Due for revisit](due-for-revisit.md) — Revisit resurface clock
* [Focus row](focus-row.md) — Detail add/remove control
* [Focus closure indicator](focus-closure-indicator.md) — latest outcome subline
* [Stale nudge](stale-nudge.md) — 7d untouched banner
* [Thread](thread.md) — v2 Connect container (not shipped)

## Capture & source text

* [rawText](raw-text.md) — plain text for LLM and in-app search
* [sourceMarkdown](source-markdown.md) — scraped Markdown cap
* [sourceContentHTML](source-content-html.md) — themed HTML for selection
* [MainContentExtractor](main-content-extractor.md) — Readability-style picker
* [titleUserSet](title-user-set.md) — preserve user-edited title

## Inference & pipeline

See [`inference/index.md`](inference/index.md) — withSession, BackgroundPipeline, KV cache, GGUF bookmark, pause, vision.

## Library & UI services

* [Library search](library-search.md) — in-app bucketing + Spotlight (extended doc)
* [filterCategory](filter-category.md) — library category filter
* [Archive](archive.md) — soft-delete retention
* [phathomDidArchiveItem](phathom-did-archive-item.md) — batch undo notification
* [LibraryBackupService](library-backup-service.md) — JSON backup v4
* [TagRelationService](tag-relation-service.md) — tag adjacency / Dive deeper
* [MediaDisplayImageLoader](media-display-image-loader.md) — Detail media decode
* [normalizedJPEGForLibraryStorage](normalized-jpeg-for-library-storage.md) — thumbnail encoding
* [MediaImageLoadMetrics](media-image-load-metrics.md) — opt-in timing

## Explicit non-goals (v1)

* [Explicit non-goals](explicit-non-goals.md) — CloudKit, embeddings, Chat tab, FoundationModels
