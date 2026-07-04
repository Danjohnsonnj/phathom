# Tag Consistency - Handoff

**Goal:** Reduce semantic drift across Phathom library tags (e.g. `ai` vs `artificial-intelligence`, `recipe` vs `recipes`) so similar items share canonical tags.

**Current phase:** Phase 1 - Audit - COMPLETE. Phase 2 - Design - COMPLETE. Phase 2 - Build (Increment 1) - **SHIPPED** (UAT passed 2026-07-04).
**Branch:** `tag-consistency` (off `main`). Increment 1 committed on this branch. Nothing pushed.
**Next action:** Decide whether to start deferred Increment 2 (tag provenance) — see tech-brief "Deferred by decision". Phase C (backlog merge) remains deferred.

**Increment 1 - what shipped (code complete 2026-06-28, Session 3):**
- 1a junk-tag: new `HTMLEntityDecoder` (`PhathomCore`); decode entities at top of `TagNameNormalizer.normalize` (backstop); decode `item.rawText` before `HashtagParser` in `mergePlatformHashtagTags`.
- 1b content-type enum: `LlamaContentAnalyzer.contentTypeVocabulary` (11 words); both `tagsTaskSuffix()` + `tagsFromDerivedTaskSuffix()` content-type CONSTRAINT rewritten strict-closed + omit-if-none.
- 1c subject seed: `TagSeedBuilder.select` (`PhathomCore`, floor 3 / cap 15, named constants) + `BackgroundPipeline.buildSubjectSeed(context:)`; `subjectSeed` threaded `ModelSession.tagsFromDerived` → `sessionGenerateTagsFromDerived` → `generateTagsFromDerived` → `tagsFromDerivedTaskSuffix(subjectSeed:)`; injects `<VOCABULARY>` block when non-empty; wired at both pipeline call sites (`applyMediaTaggingForPipelineItem`, `applyDerivedTaggingForPipelineItem`).
- Tests (appended to `PhathomTests.swift`, Swift Testing): `HTMLEntityDecoderTests`, `TagNameNormalizerEntityTests`, `TagSeedBuilderTests`. Build clean (sim); full `PhathomTests` pass.

**Manual UAT:** PASSED 2026-07-04 (3-step smoke: seed reuse, content-type enum/omit, no entity-artifact tags).

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

**Open decisions:** RESOLVED via grill (see tech-brief "Locked architecture"). Deferred by decision: Increment 2 = tag provenance (`userAddedTagNames`); Phase C = one-time backlog merge + borderline-merge calls. Content-type enum shipped with the 11-word list as specced (not revised during build).
**Last updated:** 2026-07-04: Increment 1 UAT passed; committed on `tag-consistency`.
