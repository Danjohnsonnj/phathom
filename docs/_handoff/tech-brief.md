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

## Proposed architecture (Phase 2 leading direction - not yet approved)

1. Generation-side (primary lever): give the tagger a seed/spine vocabulary and instruct "reuse an existing tag when it fits; only invent when nothing matches." Spine candidates in `canonical-map.json.proposed_spine` (~26 tags). Edit `tagsFromDerivedTaskSuffix()` / `tagsTaskSuffix()` in `LlamaContentAnalyzer.swift`; must preserve `SharedLlamaInference.withSession` serialization + KV reuse.
2. Backlog cleanup (one-time): apply `canonical-map.json` confident merges to existing items - re-point `Tag` relationships, GC orphan `Tag` rows. Likely a new global merge service (none exists today).
3. Junk-tag fix: harden tag intake so `\uXXXX` artifacts can't become tags.

Alternatives considered/secondary: post-processing canonicalization map applied in `upsertTagsOnItem`; a user-facing tag merge/rename UI. Decide scope in Phase 2.

## Hard invariants

- Audit never touches the live SwiftData store; reads exported JSON only.
- Export + findings (`tag-audit-work/`) never committed.
- Any pipeline change must preserve `SharedLlamaInference.withSession` serialization + KV reuse (repo invariants).
