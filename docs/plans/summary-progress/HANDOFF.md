---
type: Handoff
title: "Summary progress handoff"
description: "Settings-toggled library progress estimate for summary and auto-tag time."
status: stable
generated: { by: "cursor-agent", at: "2026-10-17" }
---

# Summary progress - Handoff

**Goal:** Optional Settings toggle that shows a library-list progress bar for a newly added item, estimating remaining summary and auto-tag time from a running average scaled by source length.

**Current phase:** Device UAT - passed
**Next action:** None. Feature is in the working tree, device UAT passed 2026-10-17.

**Shipped record:** [`docs/agents/product-state.md`](../../agents/product-state.md) — **Analysis progress** row.

**Hard invariants:** Do not add parallel Llama calls. Do not change KV reuse (summarize → tags → extracts). Progress UI must not alter pipeline scheduling.

**Required reading (this phase):**

- docs/plans/summary-progress/lessons.md - reusable toolkit
- docs/plans/summary-progress/product-brief.md - intent, non-goals, open decisions
- docs/plans/summary-progress/tech-brief.md - verified pipeline and UI facts

**Index (load on demand):**

- product-brief.md - background, goals, rationale, non-goals, boundaries
- tech-brief.md - current vs proposed architecture, verified findings
- phases.md - phases + per-phase verify steps
- process.md - how we work (read before committing)
- log.md - dated history of decisions/learnings/overwrites
- lessons.md - curated, accreted toolkit (carried in Required reading)

**Open decisions:** None. Model pairs are locked (filename + byte count). Detail in product-brief.md.
**Last updated:** 2026-10-17 by cursor-agent
