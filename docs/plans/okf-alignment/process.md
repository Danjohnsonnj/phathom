---
type: Process
title: "OKF alignment process"
description: How we work on this effort, including adoption mode.
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T16:30:00Z" }
---

# Process - how we work on this effort

Durable methodology. Read once per session before committing. Reached from HANDOFF.md.

**Adoption mode:** own-project

**Plan root:** `docs/plans/okf-alignment/`

## Cold-start protocol

1. Start from HANDOFF.md — the explicit entry point you are pointed at directly; read it always (phase, next action, required reading).
2. Load ONLY the leaves under HANDOFF.md "Required reading (this phase)".
3. Pull any other leaf from the Index on demand.

## Update discipline

- Briefs hold CURRENT truth: overwrite in place; correct mistakes directly.
- log.md holds HISTORY: prepend dated entries (newest first); never rewrite old sections.
- lessons.md holds the CURATED TOOLKIT: reusable gotchas and script/verify outcomes; add when useful, prune when obsolete.
- Single source of truth per fact: the next action lives only in HANDOFF.md.

## Session-handoff ritual (user-initiated wrap-up)

1. Overwrite affected brief(s) in place.
2. Refresh HANDOFF.md (phase, next action, next-phase required reading, open decisions, last-updated).
3. Prepend a dated log.md section (happened / verified / learned / overwrote).
4. Fold any reusable gotcha or script/verify outcome into lessons.md (prune obsolete ones).
5. Commit per the active adoption mode below, only when the user asks.

## Adoption mode: own-project (default)

- Artifacts are tracked and committed normally alongside code.

## Legacy path

Older single-effort trees may live at `docs/_handoff/`. New efforts use `docs/plans/<effort-slug>/`. Existing trees that still have `progress-log.md` and no `log.md` keep appending there until touched. This effort does not convert `docs/_handoff/` until that effort is wrapped.
