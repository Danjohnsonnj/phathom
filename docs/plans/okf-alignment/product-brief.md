---
type: ProductBrief
title: "OKF alignment product brief"
description: Goals, locked calls, and the frontmatter extensions still to confirm.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17T16:30:00Z" }
---

# Product brief - OKF alignment

## Background

Phathom docs are an OKF-lite wiki: concept stubs carry `type`, `title`, `description`, `tags`, and a custom `anchor`, and [`docs/agents/doc-structure.md`](../../agents/doc-structure.md) already prefers behavior over strict conformance. There is no bundle hub (`docs/index.md`), no bundle log (`docs/log.md`), and [`AGENTS.md`](../../../AGENTS.md) is still the fat cold-start map.

Two public specs exist. [OKF v0.1](https://okf.md/spec/) (also described in the [Google Cloud post](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing)) requires only `type` and recommends `title`, `description`, `resource`, `tags`, and `timestamp`. [OKF v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) keeps that shape and adds provenance (`sources`), trust (`generated`, `verified`), and lifecycle (`status`, `stale_after`). The global `okf-docs` producer profile already targets v0.2. This effort adopts that profile for Phathom and writes the repo-specific exceptions down.

## Goal

A cold-start agent opens `AGENTS.md`, follows one link into `docs/index.md`, and opens at most a few concept files whose frontmatter is the same card every time. A repo skill, pointed at from `AGENTS.md` and attached when docs change, updates that card and the indexes in the same pass. Historical archive and unfinished plans stay where they are. When a plan finishes, the durable facts are written into settled docs; the plan tree is not moved.

## Rationale

Agents already re-read `AGENTS.md`, `product-state.md`, `CONTEXT.md`, and `decisions.md` because nothing else is self-describing. A stable card lets indexes, search, and the maintenance skill share one contract. v0.2 is the version the global skill already speaks, so Phathom should not invent a third dialect.

## Non-goals

- Rewriting archive bodies or bulk-rewriting handoff specs.
- Splitting `CONTEXT.md` or `docs/decisions.md` into one file per decision.
- Attested Computation, usage counts, a visualizer, or a lint script.
- Replacing the global `okf-docs` skill. The repo skill is an overlay.
- Moving plan files into settled folders when an effort ships.

## Boundaries

- Always: code wins over docs. Update `product-state.md` before other agent docs on ship or defer. Leave `docs/archive/**` bodies frozen.
- Ask first: a new settled page that is not on the seven-event checklist; splitting a monolith; deleting or moving a doc.
- Never: treat archive or an open plan as current product truth. Drop `verified` on a human-reviewed concept without an explicit re-verify.

## Locked calls

1. **`AGENTS.md`.** Keep the hard invariants, the manual QA lists, and the issue-tracker pointer. Move the source-of-truth table and long routing prose behind `docs/index.md` and the agent guides.
2. **`docs/handoff/`.** Extra settled folder (`Handoff`, `DeliveryLog`). Add frontmatter when a file is next edited. Do not rewrite bodies in this effort.
3. **`docs/design-tokens.md`.** Stays at that path. Type `DesignTokens`. `docs/index.md` Settled links it directly (title + description), same as a folder index, so a cold start can find palette and spacing without guessing the filename.
4. **`CONTEXT.md`.** Split each glossary row into a `docs/concepts/` file. Leave `CONTEXT.md` in place as a short pointer to `docs/concepts/index.md` so existing links keep working. Do not split `docs/decisions.md`.

## Frontmatter (locked)

v0.2 card plus three extensions: `resource` (replaces `anchor`), `aliases` (only when a synonym exists), `sources` (the decision that locks the term). No shipped/deferred flag on concepts. Detail is in the tech brief.

## Success criteria

- `docs/index.md` lists Settled and In progress, and this effort appears under In progress once the hub exists.
- A new or touched settled concept uses the card in the tech brief, including a full ISO 8601 `generated.at`.
- `docs/archive/**` byte-identical except if a link from outside must change.
- Each `CONTEXT.md` term has a concept file; `CONTEXT.md` is a pointer, not a second glossary.
- `docs/index.md` Settled includes Design tokens.
- Completing a plan updates settled docs and leaves the plan directory in place.
- A cold-start read of `AGENTS.md` still surfaces the three hard invariants (`withSession`, KV reuse, no Chat tab unless asked) without opening the archive.
