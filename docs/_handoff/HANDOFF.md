# Tag Consistency - Handoff

**Goal:** Reduce semantic drift across Phathom library tags (e.g. `ai` vs `artificial-intelligence`, `recipe` vs `recipes`) so similar items share canonical tags.

**Current phase:** Phase 2 - Build (Increment 2) - **CODE COMPLETE**, awaiting manual UAT + commit.
**Branch:** `tag-consistency` (off `main`). Increment 1 committed; Increment 2 implemented uncommitted.
**Next action:** Run manual UAT (5 steps below), then commit. Merge-import note: provenance sync requires **Replace** import or manual re-edit (D8).

**Increment 2 - what shipped (code complete 2026-07-04):**
- 2a schema: additive `ContentItem.userAddedTagNames: [String]` (default `[]`, no backfill).
- 2b provenance capture: `TagProvenanceNormalizer` + Detail `saveTagChanges` / `deleteTag` (D1/D10); Add records provenance even when tag already on item from LLM.
- 2c pipeline: `buildTaggingPromptInputs` (provenance-aware subject seed + promoted content types); sticky retag via `TagPipelineMerge`; `promotedContentTypeTags` threaded through session → `tagsFromDerivedTaskSuffix` / `tagsTaskSuffix`.
- 2d backup: `formatVersion` 5; `ItemRecord.userAddedTagNames`; union restore via `TagRelationshipUpsert.attachMissingTagNames` on import.
- Tests: `TagProvenanceTests` (PhathomCore); backup v5 round-trip + union restore; migration smoke asserts empty `userAddedTagNames` on V4→V5 open. PhathomCore + PhathomTests pass; sim build clean.

**Increment 1 - shipped (UAT passed 2026-07-04):** junk-tag fix, strict-closed content-type enum, dynamic subject seed — see prior HANDOFF / progress log.

**Manual UAT (model loaded):**
1. Add tag `podcast` on item A via sheet → Regenerate tags → `podcast` remains.
2. Add `podcast` on item B → tag third item → model may use `podcast` as format (after ≥2 promotion).
3. Add singleton manual subject tag (even if LLM already used same name) → seed influence via provenance.
4. Export v5 → Replace import → provenance + sticky tags restored.
5. Merge import onto existing ID → provenance unchanged (documented D8).

**Hard invariants:** Audit reads exported JSON only - never the live SwiftData store. Export JSON + detailed findings stay OUT of git (`tag-audit-work/` gitignored). Any pipeline change must preserve `SharedLlamaInference.withSession` serialization + KV reuse.

**Findings location:** Durable summary in `tech-brief.md`. Detailed raw findings LOCAL-ONLY in `tag-audit-work/`.

**Required reading (this phase):**

- docs/\_handoff/tech-brief.md - Locked architecture (Increment 1 + 2), pipeline file paths
- docs/\_handoff/phases.md - phase objectives + verify steps
- docs/\_handoff/process.md - read before committing

**Index (load on demand):** product-brief.md · tech-brief.md · phases.md · process.md · progress-log.md

**Open decisions:** Increment 2 locked via grill 2026-07-04 (see tech-brief). Phase C (backlog merge) remains deferred.
**Last updated:** 2026-07-04: Increment 2 code complete on `tag-consistency`; awaiting UAT + commit.
