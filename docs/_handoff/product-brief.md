# Product brief - Tag Consistency

## Background

Phathom auto-tags every saved article via the LLM Analyze step. Tags are open-vocabulary: the only gate is `TagNameNormalizer` (format - lowercase, ASCII-fold, kebab-case, 2-40 chars). There is no controlled vocabulary, allow-list, or semantic canonicalization, and no global tag merge/rename. Result: the live library accumulates subtle near-duplicate tags that fragment otherwise-similar items.

## Goal

Make tags more consistent across items so semantically equivalent concepts collapse to one canonical tag. Success bar: a documented audit of real-library tag drift plus an agreed intervention that measurably reduces distinct near-duplicate clusters.

## Rationale

The user observes wide tag variation across a representative sample of saved articles. Consistent tags improve library filtering, related-items (`TagRelationService` Jaccard adjacency), and Focus Stack navigation. Doing this now, before the library grows larger, limits future cleanup cost.

## Non-goals

- Not redesigning Category (separate `@Model`, one-per-item) in this effort.
- Not building open RAG / Chat (out of scope per repo invariants).
- Not changing the on-device, privacy-first model - audit runs offline on an exported file.

## Boundaries

- Always: audit from exported JSON; keep export + findings out of git.
- Ask first: any app code change (prompt, pipeline, schema, new merge UI) - that is Phase 2+, gated on Phase 1 findings.
- Never: read or mutate the live SwiftData store from the audit; never commit the user's backup data.

## Success criteria

- Phase 1: a findings report quantifying tag drift (frequency, near-dup clusters, co-occurrence) plus a draft canonical map, reviewed by the user.
- Phase 2: a chosen intervention with rationale tied to the findings.
- Phase 3: intervention implemented and verified per simulator-verify policy.
