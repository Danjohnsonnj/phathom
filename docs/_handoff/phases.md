# Phases

## Phase 1 - Audit (discovery) - COMPLETE 2026-06-28

- Objective: quantify real-library tag drift from an exported backup and produce a draft canonical map.
- Steps: (1) user exports non-archived backup JSON; (2) run `python3 tools/tag_audit.py <export.json>`; (3) review `summary.md` / `clusters.md`; (4) LLM semantic pass over `tag_vocab.json` -> `canonical-map.json`; (5) user reviews findings.
- Verify: `summary.md` + `clusters.md` + `canonical-map.json` generated in `tag-audit-work/`. DONE.
- Result (see tech-brief.md): 564 distinct tags / 527 singletons (93%) across 115 items -> proliferation, not drift. Confident merges shave ~25. Spine + junk-tag bug identified.

## Phase 2 - Design

- Objective: choose intervention(s) tied to Phase 1 data and write the proposed architecture into tech-brief.md.
- Candidates: seed/controlled vocabulary, tightened tag prompt, post-processing canonical map in `upsertTagsOnItem`, global tag merge/rename feature.
- Verify: tech-brief.md "Proposed architecture" filled; user approves direction; UAT smoke tests defined where relevant.

## Phase 3 - Deliver

- Objective: implement the chosen intervention with tests.
- Verify: simulator build clean per `.cursor/rules/simulator-verify.mdc`; PhathomTests pass; manual QA for any filing/tag UI touched; preserves inference serialization + KV reuse.
