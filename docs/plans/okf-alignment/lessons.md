---
type: Lesson
title: "OKF alignment lessons"
description: Curated toolkit of reusable gotchas and verify outcomes.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17T16:30:00Z" }
---

# Lessons (reusable toolkit; accreted across sessions)

## Date-only generated.at is not v0.2

- Context: any concept frontmatter, including plan-build leaves.
- Lesson: `generated.at` and `verified.at` must be ISO 8601 with a zone (`2026-10-17T16:30:00Z`). A bare `2026-10-17` fails the spec. `docs/plans/summary-progress/HANDOFF.md` is the in-repo example of the short form; fix it when that tree is next touched, not in a drive-by.
- Evidence: OKF v0.2 §5 requires an explicit UTC offset. Inspected `summary-progress` frontmatter on 2026-10-17.
- Crystallize?: no

## Horizontal rules are not frontmatter

- Context: scanning `docs/` for YAML cards.
- Lesson: treat a file as a concept with frontmatter only when the first bytes are `---` and a closing `---` appears before the first heading. Handoff and archive files use `---` as markdown rules throughout the body.
- Evidence: a `^---` search on 2026-10-17 hit `docs/handoff/focus-stack.md` and `docs/archive/` many times with no opening YAML card.
- Crystallize?: no

## Do not encode shipped-vs-deferred on the concept

- Context: glossary split and any new concept frontmatter.
- Lesson: `status` is document readiness (`draft` / `stable` / `deprecated`). Whether a feature shipped lives only in `docs/agents/product-state.md`. A second flag on the concept will drift.
- Evidence: `product-state.md` already owns Focus shipped vs Chat deferred. CONTEXT non-goals repeat that prose.
- Crystallize?: no

## Path is identity

- Context: promoting a finished plan or “settling” a handoff.
- Lesson: write the durable fact into the settled file and link back. Do not move the plan or handoff file. Deprecate a WIP leaf only when it would still be mistaken for current instructions.
- Evidence: global `okf-docs` producer profile, settle-without-move. Phathom `doc-structure.md` already refuses archive body rewrites.
- Crystallize?: no
