---
type: Handoff
title: "OKF alignment handoff"
description: "Align Phathom docs with OKF v0.2: stable frontmatter, a repo skill, and a keep-or-leave migration."
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T16:30:00Z" }
---

# OKF alignment - Handoff

**Goal:** Make `docs/` a conformant OKF v0.2 bundle with one stable frontmatter card, a repo-local skill that keeps it current, and a migration that leaves archive and in-flight plans alone.

**Current phase:** Done
**Next action:** None

**Hard invariants:** Do not rewrite `docs/archive/**` bodies. Do not move files to settle them (path is identity). Do not split `docs/decisions.md`. `CONTEXT.md` is a pointer to `docs/concepts/`. Code stays above docs.

**Required reading (this phase):**

- docs/plans/okf-alignment/lessons.md - reusable toolkit
- docs/plans/okf-alignment/tech-brief.md - frontmatter card, skill shape, folder map
- CONTEXT.md - pointer to docs/concepts/index.md

**Index (load on demand):**

- product-brief.md - background, goals, rationale, non-goals, boundaries
- tech-brief.md - current vs proposed architecture, verified findings
- phases.md - phases + per-phase verify steps
- process.md - how we work (read before committing)
- log.md - dated history of decisions/learnings/overwrites
- lessons.md - curated, accreted toolkit (carried in Required reading)

**Locked:** `AGENTS.md` keeps invariants, QA, and the tracker, and points at the hub. `docs/handoff/` gets frontmatter on touch only. `design-tokens.md` stays put as `DesignTokens` and is linked from `docs/index.md`. `CONTEXT.md` terms split into `docs/concepts/`; the root file remains as a pointer.

**Open decisions:** None. Frontmatter card is locked in the tech brief (`resource`, `aliases`, `sources` only).

**Last updated:** 2026-10-17 (Phases 4–5 complete; effort done) by cursor-agent
