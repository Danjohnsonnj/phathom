# Annotated Markdown Export — Handoff

**Goal:** Export web articles from Detail as annotated markdown (`==highlight==` + footnotes for notes) for colleague sharing and personal drafting.

**Current phase:** Phase 2 — Build — **CODE COMPLETE**, awaiting manual UAT.
**Branch:** `annotated-markdown-export` (off `main`).
**Next action:** Run manual UAT (8 steps in phases.md § Phase 3), then commit when user asks.

**Increment 1 — shipped (code complete 2026-07-08):**
- `AnnotatedMarkdownExporter` + `HighlightExportInput` in PhathomCoreMarkdown.
- `AnnotatedMarkdownExporterTests` (9 cases) pass.
- Detail `DetailOverflowMenu`: Share link + Export markdown.
- iOS share sheet for `.md`; macOS `fileExporter`.
- Sim + macOS builds clean.

**Hard invariants:** No schema migration; no pipeline/inference changes; exporter is read-only.

**Required reading (this phase):**

- docs/_handoff/tech-brief.md — locked format spec + file paths
- docs/_handoff/phases.md — objectives + verify steps
- docs/_handoff/process.md — read before committing
- docs/_handoff/lessons.md — accreted gotchas

**Index (load on demand):** product-brief.md · tech-brief.md · phases.md · process.md · progress-log.md · lessons.md

**Open decisions:** None — format locked via grill 2026-07-08; dialect reaffirmed 2026-07-17 (`==` + footnotes; portable/`<mark>`/dual profiles deferred) — [`docs/decisions.md`](../decisions.md).
**Last updated:** 2026-07-17 — Dialect decision recorded; still awaiting manual UAT.
