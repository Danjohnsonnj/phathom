---
type: Glossary
title: Library search
description: In-app Library search and CoreSpotlight indexing — fields, scope, and result shape.
tags: [library, search, spotlight]
anchor: Phathom/Phathom/Services/LibrarySearchService.swift
---

# Definition

Phathom exposes **two search surfaces**. Both surface **`ContentItem`** library rows — never standalone **`Highlight`** rows.

## In-app search (Library tab)

**Entry:** **`PinnedLibrarySearchBar`** on **`LibraryTab`** → **`LibrarySearchService.bucket`**.

**Result shape:** one row per matching **`ContentItem`**, even when the match came from a highlight note on that item.

**Matching (Stage 1):** trimmed query, lowercased, **substring** match (`contains`) on each candidate after kind / **`ReadStatus`** / category filters:

| Field | Searched |
|-------|----------|
| **`displayTitle`** | Yes |
| **`rawText`** | Yes |
| **`displayHost`** | Yes |
| **`originalURL`** (absolute string) | Yes |
| **`mediaDescription`** | Yes |
| Tag names (`tagNames`) | Yes |
| Highlight **`userNote`** (non-empty, trimmed) | Yes |
| Highlight **`quotedText`** | No |
| **`summaryBullets`** | No |
| **`extracts`** | No |
| **`sourceMarkdown`** | No (search uses **`rawText`**, not stored markdown) |
| Structural **`category`** name | No (category is a **filter**, not a search field) |

**Empty query:** returns all items passing active filters; no adjacent section.

**Tag adjacency:** when the query exactly matches a known tag name, **`Sections.adjacent`** lists up to 8 related items (Jaccard vs anchors via **`TagRelationService.computeAdjacent`**).

**Dive deeper (Stage 2):** optional async Llama tag expansion — **`LibrarySearchService.diveDeeper`** → **`TagRelationService.expandAndRankAdjacent`** (primary GGUF only). On failure, Stage 1 adjacent order is kept.

**Scope:** **`LibraryTab`** `@Query` excludes **`isArchived`** items. Archived / Recently Deleted items are not in the in-app search pool.

**Notebook tab:** no search box — highlights are browsable with shared filter chrome only (**2026-05-30** decision).

## System search (Spotlight / App Intents)

**Indexer:** **`ContentItem.indexInSpotlight()`** (`ContentItem+Spotlight.swift`).

**Indexed per item:**

| Attribute | Source |
|-----------|--------|
| Title | **`displayTitle`** |
| Description | First **`displaySummaryBullets`** entry, else sanitized **`mediaDescription`** |
| Keywords | Tag names only — structural **`category`** omitted deliberately |
| Thumbnail | **`thumbnailData`** when present |

**Not indexed:** **`rawText`**, highlight notes, highlight quoted text, URL/host, **`extracts`**, category name.

**Deep link:** Spotlight tap and **`OpenPhathomItemIntent`** → **`MainTabView`** sets **`libraryDeepLinkID`** → Library tab → **`DetailView`** for that item.

**Archive:** **`removeFromSpotlight()`** on archive; **`indexInSpotlight()`** on restore only when **`processingStatus == .completed`**.

# Links

- Code: [`LibrarySearchService.swift`](../../Phathom/Phathom/Services/LibrarySearchService.swift) · [`LibraryTab.swift`](../../Phathom/Phathom/Views/Library/LibraryTab.swift) · [`ContentItem+Spotlight.swift`](../../Phathom/PhathomCore/Sources/PhathomCore/ContentItem+Spotlight.swift) · [`ArchiveRetention.swift`](../../Phathom/Phathom/Services/ArchiveRetention.swift)
- Decisions: [Spotlight keywords omit category](../decisions.md#decision-log) · [Archive + Spotlight](../decisions.md#decision-log) · [TagRelationService + Dive deeper](../decisions.md#decision-log) · [Notebook no search](../decisions.md#decision-log)
- Related: [`TagRelationService`](../CONTEXT.md#library--ui-services) · [`rawText`](../CONTEXT.md#capture--source-text)
- Pitfalls: recall agentmemory tags `LibrarySearchService`, `Spotlight` (do not duplicate here)
