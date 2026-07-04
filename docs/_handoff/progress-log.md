# Progress log (append-only, newest last)

## 2026-06-28 - Session 1: Effort setup

- Happened: Stood up the tag-consistency plan-build tree (`docs/_handoff/*`) + AGENTS.md pointer. Explored tag pipeline + export schema (read-only). Wrote `tools/tag_audit.py` and gitignored `tag-audit-work/`.
- Learned: Tags are open-vocabulary (`Tag` `@Model`, format-only `TagNameNormalizer`, no controlled vocabulary or global merge). Export is `formatVersion 4` JSON with `items[].tags: [String]`; archived items excluded. Root cause of drift = no semantic canonicalization.
- Overwrote: none (initial).

## 2026-06-28 - Session 1: Export received

- Happened: User exported full library backup (28MB) to `~/Downloads/phathom-library-backup-2026-06-29T00-44-53Z.json`. Path recorded in HANDOFF.md; ran `tools/tag_audit.py`.
- Learned: 115 items, 656 tag uses, 564 distinct tags, **527 singletons (93% used once)**, avg 5.70 tags/item. Dominant problem is NOT subtle near-dups but hyper-specific one-off tags (`ai-nuclear-lessons`, `park-development`, `ai-executive-disconnection`). Real morphology dups exist but are few (llm/llms, code-review/code-reviews, open-weight/open-weights, context-window-limitation(s), human-in/on-the-loop). Top reused tags: agentic-coding x17, llm x10, software-development x8, artificial-intelligence x8.
- Overwrote: HANDOFF.md phase -> in progress + export-file pointer + next action. Fixed a defect in `tools/tag_audit.py`: removed transitive whole-token containment merge (short tags like `ai`/`development` chained everything into one 170-member blob). Clusterer is now high-precision: plural/singular + tight fuzzy only; conceptual grouping deferred to LLM pass.

## 2026-06-28 - Session 1: LLM semantic pass

- Happened: Ran LLM semantic clustering over `tag_vocab.json` -> `tag-audit-work/canonical-map.json` (16 confident merges, 8 borderline groups, proposed 26-tag "spine", junk-drop list).
- Learned: Top reused tags (agentic-coding x17, llm x10, artificial-intelligence x8, software-development x8) form a clear spine. Confident merges only shave ~25 tags off 564 - confirming the problem is generation-side proliferation, not cleanable drift. Found a pipeline BUG: unicode escape artifacts (`x201c`=", `x201d`=", `x2019`='`, `x1f517`=link-emoji) leaked into tags despite TagNameNormalizer; worth a Phase 2/3 fix.
- Overwrote: HANDOFF.md phase/next action -> findings ready, awaiting user review.

## 2026-06-28 - Session 1: Wrap-up / cold-start handoff prepared

- Happened: Closed Phase 1. Promoted durable design inputs (metrics, reused-spine, confident merge canonicals, junk-tag bug, proposed Phase 2 architecture with file paths) from gitignored `tag-audit-work/` into committed `tech-brief.md`. Refreshed HANDOFF (Phase 2 - Design not started; next action = spec seed/spine-vocabulary tag prompt) and `phases.md` (Phase 1 COMPLETE).
- Learned: Detailed findings are gitignored, so resumability requires the summary live in a committed brief; added a "Findings location" + regeneration note to HANDOFF so a cold-start agent can rebuild `tag-audit-work/` from the export + script + semantic-pass prompt.
- Overwrote: HANDOFF current phase / next action / required reading / open decisions; phases.md Phase 1 status; tech-brief Proposed architecture + new Phase 1 results section.
- Not committed (user said "commit later"). Open: confirm committing the spine/summary in tech-brief vs keeping fully local.

## 2026-06-28 - Session 2: Phase 2 design locked + plan approved + work split to branch

- Happened: Grilled the Phase 2 design to resolution (10 decisions). Wrote an implementation plan, ran a standalone plan review (gates 1-5 pass; 3 minor clarifications applied). Split the working tree: doc/tooling hygiene -> `main` (`797435f`); handoff tree + `tag_audit.py` + AGENTS.md handoff pointer + `tag-audit-work/` gitignore -> new branch `tag-consistency` (`d376f0a`). Neither pushed.
- Decisions (locked; full detail in tech-brief "Locked architecture"): scope = generation fix + junk-tag fix now, backlog merge deferred to Phase C; mechanism = strict-closed content-type enum + soft dynamic subject seed; subject seed source = dynamic from user's own library (floor 3, cap 15, named constants); content-type = strict closed 11-word list, omit-if-none; junk-tag root cause = undecoded HTML hex entities, fix = entity decode at intake + normalizer backstop; tag provenance (user-added tags as priority signal) = deferred Increment 2; borderline merges = deferred to Phase C; commit = handoff tree + script (done), tag-audit-work stays gitignored; verify = unit tests (Swift Testing) + 3-step manual UAT.
- Learned: `tagsTaskSuffix()`/`generateTags()` full-article path has no live caller (pipeline tags only via `tagsFromDerived`). Two tagging call sites (`applyMediaTaggingForPipelineItem` L1187, `applyDerivedTaggingForPipelineItem` L1233); `performRetag` L906 routes through them. PhathomTests use Swift Testing (`@Test`/`#expect`), not XCTest. Tagging runs under optional `.taggingPreferred` GGUF (decisions.md L67) but seed is library-derived/model-agnostic, so no conflict.
- Overwrote: HANDOFF phase/next action/open decisions (-> design complete, build not started, branch noted); tech-brief Proposed architecture -> Locked architecture.
- Next session: build Increment 1a (junk-tag fix) first on branch `tag-consistency`. Plan file (host-local, optional): `~/.cursor/plans/tag_consistency_generation_fix_97587f9b.plan.md`.

## 2026-06-28 - Session 3: Phase 2 Increment 1 implemented (1a+1b+1c)

- Happened: Built all three sub-increments on `tag-consistency`. 1a: added `HTMLEntityDecoder` (`PhathomCore`; numeric decimal, hex, common named entities, malformed passthrough), decode at top of `TagNameNormalizer.normalize`, decode `rawText` before `HashtagParser` in `mergePlatformHashtagTags`. 1b: `LlamaContentAnalyzer.contentTypeVocabulary` (11 words) + rewrote content-type CONSTRAINT in both `tagsTaskSuffix()` and `tagsFromDerivedTaskSuffix()` to strict-closed/omit-if-none. 1c: `TagSeedBuilder.select` (`PhathomCore`; floor/cap named constants, count-desc → shorter → lexicographic ordering) + `BackgroundPipeline.buildSubjectSeed(context:)`, threaded `subjectSeed` through the session chain into `tagsFromDerivedTaskSuffix(subjectSeed:)` (injects `<VOCABULARY>` block when non-empty), wired both pipeline call sites. Added 3 Swift Testing suites to `PhathomTests.swift`. Build (sim) clean; full `PhathomTests` passed.
- Learned: PhathomCore is a SwiftPM target → new source files auto-compile (no `.pbxproj` edit); appended tests to the existing `PhathomTests.swift` to avoid registering a new file in the Xcode project. Confirmed no separate article-body entity-decode needed: derived path is LLM-generated, and the `TagNameNormalizer` backstop catches any stray entity. KV-reuse invariant preserved (tags suffixes are not part of `analyzeArticle`'s shared `<ARTICLE>` prefix).
- Overwrote: HANDOFF phase/next action/last-updated (→ Increment 1 code complete, awaiting UAT + commit), open-decisions (content-type list shipped as specced).
- Not committed (user said "resume work and build", not commit). Open: run 3-step manual UAT, then commit code + docs.

## 2026-07-04 - Session 4: Increment 1 UAT + commit

- Happened: User signed off 3-step manual UAT (seed reuse, content-type enum/omit, no entity-artifact tags). Committed Increment 1 code + handoff doc updates on `tag-consistency`.
- Learned: none new.
- Overwrote: HANDOFF phase/next action/UAT status/last-updated (-> Increment 1 shipped).
