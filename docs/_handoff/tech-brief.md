# Tech brief - current state and gaps

## Current architecture (verified)

- **Tag model** - separate normalized `@Model`, `name` is `.unique`, many-to-many with `ContentItem`; deduped globally (`Phathom/PhathomCore/Sources/PhathomCore/Tag.swift`).
- **TagNameNormalizer** - canonical format gate: trim, strip leading `#`, diacritic-fold, lowercase, map non-`[a-z0-9-]` to `-`, collapse/trim hyphens, require 2-40 chars else drop (`Phathom/PhathomCore/Sources/PhathomCore/TagNameNormalizer.swift`).
- **Tag generation** - LLM emits a JSON string array; `tagsFromDerivedTaskSuffix()` (derived path, primary) and `tagsTaskSuffix()` (full-article path) in `Phathom/Phathom/Inference/LlamaContentAnalyzer.swift`. Optional separate tagging GGUF (`phathom.selectedGGUFBookmark.tagging`), silent fallback to primary model.
- **Persistence gate** - `upsertTagsOnItem` normalizes + dedups + reuses existing `Tag` rows; `mergePlatformHashtagTags` appends IG/TikTok caption hashtags (`Phathom/Phathom/Services/BackgroundPipeline.swift`).
- **Manual edit** - Detail tag editing (`DetailView.swift`, `TagEditSheet.swift`, `TagChipsView.swift`); edit re-points one item, does NOT rename the shared `Tag` row; "Regenerate tags" re-runs LLM.
- **Tag relatedness** - `TagRelationService` / `TagAdjacency` compute Jaccard adjacency + LLM semantic expansion (read-only; never mutates tags).
- **Backup/export** - `LibraryBackupService` (`PhathomCore`), `formatVersion 4`, single pretty-printed JSON (`.prettyPrinted, .sortedKeys`, iso8601). Excludes archived items (`isArchived == false`).

## Verified findings / gaps

1. No controlled vocabulary / allow-list anywhere - tags are open-vocabulary; only format is enforced, not semantics. ROOT CAUSE of drift. (verified)
2. No global tag merge/rename - only per-item re-pointing; orphan `Tag` rows not GC'd on edit. (verified)
3. Export tag shape: each item has `tags: [String]` at `items[].tags` (`LibraryBackupService.swift` `ItemRecord.tags = item.tags.map(\.name)`). Category is separate: `categoryName: String?`. (verified)
4. Import re-normalizes with `lowercased().trimmingCharacters` only (not full `TagNameNormalizer`); seed/older data may contain spaces -> audit must treat tags as arbitrary strings, not assume kebab-case. (verified)

## Export schema (audit input)

```json
{ "formatVersion": 4, "exportedAt": "iso8601", "appBuild": "optional",
  "items": [ { "id": "...", "title": "...", "tags": ["climate-change","news"], "categoryName": "optional", "contentKind": "web", ... } ] }
```

Audit needs only `items[].tags`. File may be large (full article text dominates size); tags themselves are tiny.

## Audit script contract (`tools/tag_audit.py`)

- Input: path to export JSON. Output dir: `tag-audit-work/` (default; gitignored).
- Memory-safe for huge files: prefers `ijson` streaming if installed; falls back to `json.load` with a warning. Stdlib-only otherwise (uses `difflib`).
- Produces:
  - `frequency.tsv` - tag, count (items using it).
  - `clusters.md` - deterministic near-dup clusters: plural/singular, substring/containment, fuzzy (difflib ratio >= threshold), shared-token groups.
  - `cooccurrence.tsv` - top tag pairs that co-occur on items.
  - `tag_vocab.json` - compact `[{tag,count}]`, the small artifact handed to the LLM semantic pass.
  - `summary.md` - headline metrics (total items, total tag uses, distinct tags, singletons, largest clusters).

## LLM semantic clustering pass (Phase 1 stage 2)

Deterministic clustering misses synonyms (`ml` ~ `machine-learning`, `llm` ~ `large-language-models`). After running the script, feed `tag_vocab.json` to an LLM with this instruction, producing a canonical map `{variant -> canonical}`:

> Given this list of `{tag, count}` from a personal article library, group tags that refer to the same concept (synonyms, abbreviations, singular/plural, broader/narrower where a merge is clearly safe). For each group choose ONE canonical tag (prefer the most frequent, most specific, kebab-case form). Output JSON: a list of groups, each `{canonical, variants:[...], rationale}`. Do NOT merge genuinely distinct concepts; when unsure, leave a tag in its own group. Flag ambiguous borderline merges separately for human review.

Output saved to `tag-audit-work/canonical-map.json` (untracked). This map is the input to the Phase 2 design decision.

## Phase 1 audit results (2026-06-28, export `phathom-library-backup-2026-06-29T00-44-53Z.json`)

Durable summary so a cold-start agent has the numbers without the gitignored `tag-audit-work/`. Raw findings (full 564-tag vocab, per-item data) are local-only; regenerate by re-running `tools/tag_audit.py <export>` then the LLM semantic pass (prompt below).

- 115 items, 656 tag uses, **564 distinct tags, 527 singletons (93% used once)**, avg 5.70 tags/item.
- Diagnosis: problem is generation-side PROLIFERATION (LLM mints hyper-specific one-off tags), not cleanable near-dup drift. Confident semantic merges only shave ~25 tags.
- Reused spine (top): agentic-coding x17, llm x10, software-development x8, artificial-intelligence x8, software-engineering x6, productivity x6, opinion x5.
- Confident merge canonicals (from `canonical-map.json`): ai/ai-tool->artificial-intelligence; llms/ai-llm/language-models->llm; coding-agent/ai-coding-agents->coding-agents; agentic-programming->agentic-coding; agent-generated-code->ai-generated-code; code-reviews->code-review; open-weight/llm-open-weights->open-weights; foodreview->food-review; opinion-piece->opinion; tech->technology; new-jersey-park/state-park->new-jersey-state-park.
- Borderline (defer to user): software-development vs software-engineering; human-in vs on-the-loop; ai-assisted vs agentic-coding; local-first cluster.
- BUG: unicode-escape artifacts leaked into tags despite `TagNameNormalizer`: `x201c` (left double-quote), `x201d` (right double-quote), `x2019` (apostrophe), `x1f517` (link emoji). Investigate where raw `\uXXXX`-style tokens enter tagging (LLM output decode or `mergePlatformHashtagTags`).

## Locked architecture (Phase 2 Increment 1) - approved 2026-06-28

Decisions reached via grill; plan reviewed (gates 1-5 pass). Scope = generation-side fix + junk-tag fix only. Three landable sub-increments, smallest-first. No SwiftData schema change. Preserve `SharedLlamaInference.withSession` serialization + KV reuse (seed/enum live only in the tags task suffix, after the shared prefix).

**1a - Junk-tag fix (ship first, independent).** Root cause confirmed: undecoded HTML hex entities in scraped text reach tag intake (`&#x201C;`->`x201c`, `&#x2019;`->`x2019`, `&#x1F517;`->`x1f517`); `&`/`#`/`;` map to hyphens but the hex payload survives. Fix (defense-in-depth):
- New `HTMLEntityDecoder` in `PhathomCore` (numeric `&#NNN;`, hex `&#xHHHH;`, common named).
- Backstop: decode entities at top of `TagNameNormalizer.normalize` (`PhathomCore/.../TagNameNormalizer.swift`) - the single chokepoint all tags pass through.
- Source: decode `item.rawText` before `HashtagParser.tagNames(in:)` in `mergePlatformHashtagTags` (`BackgroundPipeline.swift` ~L1301). Confirm/handle article-body path during build if it also carries entities.

**1b - Strict-closed content-type enum (prompt-only).** Add `contentTypeVocabulary = [news, opinion, analysis, guide, tutorial, review, interview, explainer, reference, recipe, social-media]` (revisit vs audit data) in `LlamaContentAnalyzer.swift`. Rewrite content-type CONSTRAINT in `tagsFromDerivedTaskSuffix()` (L197) and `tagsTaskSuffix()` (L163): pick 1-2 content-type tags ONLY from the list; if none fit, omit (never invent). NOTE: `tagsTaskSuffix()`/`generateTags()` full-article path is currently uncalled (pipeline tags only via `tagsFromDerived`); update for parity, expect no runtime effect.

**1c - Dynamic subject seed.** Pure selector `TagSeedBuilder.select(from:[(name,count)], floor: 3, cap: 15) -> [String]` (exclude < floor, sort count desc then shorter/kebab; floor/cap named constants). `buildSubjectSeed(context:)` fetch wrapper reads `Tag` + `t.items.count`. Thread `subjectSeed` through `ModelSession.tagsFromDerived` (L41) -> `sessionGenerateTagsFromDerived` (L312) -> `generateTagsFromDerived` (L317) -> `tagsFromDerivedTaskSuffix(subjectSeed:)`. Build seed at the two call sites: `applyMediaTaggingForPipelineItem` (L1187) + `applyDerivedTaggingForPipelineItem` (L1233); `performRetag` (L906) covered transitively. Suffix adds `<VOCABULARY>` block "prefer reusing a subject tag when it genuinely fits; only invent when none apply"; empty seed -> omit block (cold start). Rationale: local single-user library, so the user's own frequently-reused tags ARE the correct spine; the floor excludes the 527 singletons (the disease), breaking the proliferation loop. Borderline merges become moot (both variants coexist in seed if frequent, else fade).

**Tests (Swift Testing, `Phathom/PhathomTests/`):** `TagSeedBuilderTests`, `TagNameNormalizerTests` (entity cases), `HTMLEntityDecoderTests`. Plus 3-step manual UAT (reuse / content-type / no-artifacts).

**Deferred by decision:**
- Increment 2 (next, before backlog): tag provenance. Additive `ContentItem.userAddedTagNames: [String]` (lightweight migration); user-added tags bypass the floor and can expand the content-type set. Captured at `TagEditSheet` save. Rationale: intentional curation is a stronger signal than frequency and is the principled escape hatch for content-type rigidity - but needs schema, so it rides on top of a proven base mechanism.
- Phase C: one-time backlog merge (new global merge service: re-point `Tag` rels, GC orphans) applying `canonical-map.json` confident merges; resolve borderline merges then. Possible human-gated content-type enum-gap flagging via the audit.

## Hard invariants

- Audit never touches the live SwiftData store; reads exported JSON only.
- Export + findings (`tag-audit-work/`) never committed.
- Any pipeline change must preserve `SharedLlamaInference.withSession` serialization + KV reuse (repo invariants).
