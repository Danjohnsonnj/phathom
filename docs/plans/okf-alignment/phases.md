---
type: Phases
title: "OKF alignment phases"
description: Phase objectives and verify steps.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17T16:30:00Z" }
---

# Phases

## Phase 1 - Lock the profile

- Done 2026-10-17. Locked: short `AGENTS.md`, handoff frontmatter on touch, `DesignTokens` linked from the hub, split `CONTEXT.md` into concept files, and the frontmatter card (`resource`, `aliases`, `sources` only).
- Verify: HANDOFF open decisions is None. No files outside this plan changed.

## Phase 2 - Hub, skill, AGENTS pointer

- Add `docs/index.md` (`okf_version: "0.2"`, Settled and In progress) and `docs/log.md`.
- Add `.cursor/skills/docs-maintenance/SKILL.md` with the locked card, allow-list, and migration exceptions.
- Trim `AGENTS.md` per the locked call. Keep invariants, QA, and the tracker pointer. Point Docs at the skill and the hub.
- Extend `.cursor/rules/doc-hygiene.mdc` to `docs/**/*.md` and point it at the skill.
- Append a docs subsection to `README.md` only if it has no docs link. Do not stub the README.
- List this effort under In progress.
- Verify: `AGENTS.md` still states `withSession`, KV reuse, and no Chat tab unless asked. `docs/archive/` is absent from Settled. `git diff -- docs/archive` is empty.

## Phase 3 - Frontmatter on live settled files, and the glossary split

- Existing concept stubs: `anchor` → `resource`, add `status` and `generated`. Set `type: Invariant` where the stub is a hard invariant. Add `aliases` or `sources` only when the row already has a synonym or a decision link.
- Split `CONTEXT.md` rows into `docs/concepts/` (one term per file, grouped by the current sections). Inference stubs that already exist stay; do not duplicate them. Non-goals can share one `explicit-non-goals.md` instead of four one-line files.
- Replace `CONTEXT.md` body with a pointer to `docs/concepts/index.md`. Keep the path.
- Add the card to `product-state.md`, `decisions.md`, and `design-tokens.md`. Link Design tokens from `docs/index.md` Settled and from `docs/concepts/index.md`.
- Verify: every former `CONTEXT.md` term resolves from the concepts index. `CONTEXT.md` no longer holds the tables. A sample concept has the five required keys. `docs/index.md` Settled lists Design tokens.

## Phase 4 - On-touch manifest for the rest

- Write a disposition table into this tech brief (or a leaf if it outgrows it): each `docs/handoff/*.md`, `docs/agents/assessment-*.md`, and `docs/design-tokens.md` as touch-later, with the type to apply.
- Do not edit those bodies in this phase unless the user asks to convert one file as the sample.
- Verify: the table names every markdown file under `docs/handoff/` and `docs/agents/` that Phase 3 did not convert.

## Phase 5 - Promotion rule, exercised once

- Pick one finished plan (`summary-progress`, whose device UAT already passed and whose facts are already in `product-state.md`). Confirm settled docs hold the durable facts, link from the plan, and leave the plan directory in place.
- Leave `docs/_handoff/` unchanged until that effort is wrapped on its own.
- Verify: `docs/plans/summary-progress/` still exists. `product-state.md` mentions analysis progress. No file moved from `plans/` into `concepts/` or `agents/`.
