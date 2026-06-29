# Tag Consistency - Handoff

**Goal:** Reduce semantic drift across Phathom library tags (e.g. `ai` vs `artificial-intelligence`, `recipe` vs `recipes`) so similar items share canonical tags.

**Current phase:** Phase 1 - Audit - COMPLETE. Phase 2 - Design - COMPLETE (decisions locked, plan approved). Phase 2 - Build - NOT STARTED.
**Branch:** `tag-consistency` (off `main`). Unrelated doc/tooling hygiene already on `main`; handoff tree + `tag_audit.py` committed on this branch. Neither pushed.
**Next action:** Implement Phase 2 Increment 1 on branch `tag-consistency`, smallest-first: (1a) junk-tag fix, (1b) content-type enum, (1c) dynamic subject seed. Full step-by-step plan with file paths/line numbers + decision rationale is in `tech-brief.md` "Locked architecture (Phase 2 Increment 1)". Start with Increment 1a.

**Hard invariants:** Audit reads exported JSON only - never the live SwiftData store. Export JSON + detailed findings stay OUT of git (`tag-audit-work/` gitignored). Any pipeline change must preserve `SharedLlamaInference.withSession` serialization + KV reuse.

**Findings location:** Durable summary (metrics, spine, confident merges, junk-tag bug) is in `tech-brief.md`. Detailed raw findings are LOCAL-ONLY in `tag-audit-work/` (`summary.md`, `clusters.md`, `frequency.tsv`, `tag_vocab.json`, `canonical-map.json`). If missing on cold start, regenerate: `python3 tools/tag_audit.py <export.json>` then the LLM semantic pass (prompt in `tech-brief.md`).

**Required reading (this phase):**

- docs/\_handoff/tech-brief.md - Phase 1 results, spine, confident merges, junk-tag bug, proposed architecture, pipeline file paths
- docs/\_handoff/phases.md - phase objectives + verify steps
- docs/\_handoff/product-brief.md - boundaries (ask-first before any app code)

**Index (load on demand):**

- product-brief.md - background, goal, non-goals, boundaries, success criteria
- tech-brief.md - current vs proposed architecture, verified findings, script contract
- phases.md - phases + per-phase verify steps
- process.md - how we work (read before committing)
- progress-log.md - dated history of decisions/learnings/overwrites

**Open decisions:** RESOLVED via grill (see tech-brief "Locked architecture"). Deferred by decision: Increment 2 = tag provenance (`userAddedTagNames`); Phase C = one-time backlog merge + borderline-merge calls. Content-type enum word list may be revisited against audit data during build.
**Last updated:** 2026-06-28, Session 2: Phase 2 design grilled + locked, plan approved + reviewed, work split to `tag-consistency` branch. Ready to build.
