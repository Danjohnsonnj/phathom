# Tag Consistency - Handoff

**Goal:** Reduce semantic drift across Phathom library tags (e.g. `ai` vs `artificial-intelligence`, `recipe` vs `recipes`) so similar items share canonical tags.

**Current phase:** Phase 1 - Audit - COMPLETE. Phase 2 - Design - not started.
**Next action:** Spec the Phase 2 generation-side fix: give the tagger a seed/spine vocabulary (~26 tags in `tech-brief.md` Phase 1 results) and instruct "reuse an existing tag when it fits; only invent when nothing matches." Resolve the 4 borderline merge groups with the user, then write the design into `tech-brief.md` "Proposed architecture". No app code until the user approves the design.

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

**Open decisions:** (1) Final spine vocabulary contents. (2) 4 borderline merges: software-development vs software-engineering; human-in vs on-the-loop; ai-assisted vs agentic-coding; local-first cluster. (3) Phase 2 scope - generation fix only, or also one-time backlog merge + junk-tag fix. (4) Whether to commit the spine/findings summary (user chose detailed findings stay untracked; tech-brief currently holds the generic summary - confirm before committing).
**Last updated:** 2026-06-28, Phase 1 complete (audit + semantic pass), handoff prepared.
