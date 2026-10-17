---
name: docs-maintenance
description: Repo-specific OKF documentation rules. Use when updating this repo's docs/, wrapping up a session, or applying the seven-event checklist. Defers shared protocol to the global okf-docs skill.
---

# Docs maintenance (Phathom)

Repo-local overlay. Shared protocol: global `okf-docs` (producer profile, seven-event checklist, routing, on-write). This file holds **only** what is unique to this repo.

## Authority

1. **Swift source** (`Phathom/`)
2. [`docs/decisions.md`](../../../docs/decisions.md)
3. Active handoff / plan next action ([`docs/handoff/`](../../../docs/handoff/index.md), [`docs/plans/`](../../../docs/plans/))
4. Concept stubs ([`docs/concepts/`](../../../docs/concepts/index.md))
5. [`README.md`](../../../README.md) — human orientation

[`CONTEXT.md`](../../../CONTEXT.md) is a pointer to [`docs/concepts/`](../../../docs/concepts/index.md). **Agentmemory** never overrides code or `docs/decisions.md`.

Hub entry: [`docs/index.md`](../../../docs/index.md).

## Frontmatter card (locked)

OKF requires `type`. On every **new or touched** concept (not reserved `index.md` / `log.md`):

| Field | Rule |
| ----- | ---- |
| `type` | Required; must match folder allow-list below |
| `title` | Required |
| `description` | Required; one sentence |
| `status` | Required: `draft` \| `stable` \| `deprecated` (absent treated as `stable`) |
| `generated` | Required: `by` (`cursor-agent` \| `human:<id>` \| `process:<id>`) and `at` (**ISO 8601 with zone**, e.g. `2026-10-17T16:30:00Z`) |

**Extensions only** (do not add other keys without updating this skill and the okf-alignment tech brief):

| Extension | Rule |
| --------- | ---- |
| `resource` | One repo-relative Swift path (replaces legacy `anchor`) |
| `aliases` | Short list when a real synonym exists; **omit the key** when none |
| `sources` | Decision row that locks the term (`id`, `resource`, `title`); omit when none |

Optional: `tags`, `verified`, `stale_after`. **Do not** add `timestamp`, `anchor`, `layer`, or a shipped/deferred product flag (that lives in [`product-state.md`](../../../docs/agents/product-state.md)).

Bundle-root [`docs/index.md`](../../../docs/index.md) may set only `okf_version: "0.2"`. [`docs/log.md`](../../../docs/log.md) has no concept frontmatter.

## Type-folder allow-list

| Path | Allowed `type` |
| ---- | -------------- |
| `docs/concepts/` | `Glossary`, `Invariant`, `Module`, `Architecture`, `Lesson` |
| `docs/agents/` | `AgentGuide`, `ProductState` |
| `docs/runbooks/` | `Runbook`, `Playbook` (create folder index when first runbook is real) |
| `docs/decisions.md` | `DecisionLog` |
| `docs/design-tokens.md` | `DesignTokens` |
| `docs/handoff/` | `Handoff`, `DeliveryLog` |
| `docs/plans/<slug>/` | Plan-build leaves: `Handoff`, `ProductBrief`, `TechBrief`, `Phases`, `Process`, `DeliveryLog`, `Lesson` |
| `docs/archive/` | **none** — not in Settled index; no frontmatter pass |

Plan effort `log.md` files stay reserved chronology (no YAML `type`).

## Commands (doc-adjacent)

Staleness sweep and fix tiers: [`docs/agents/doc-structure.md`](../../../docs/agents/doc-structure.md).

## Migration exceptions

- **`docs/archive/**`** — frozen; do not rewrite bodies.
- **`docs/_handoff/`** — leave until that effort wraps; not linked from the hub Settled list.
- **Open `docs/plans/`** — WIP; do not move files to “settle” them (path is identity).
- **Do not split** [`docs/decisions.md`](../../../docs/decisions.md).

## Promotion (plans → settled docs)

When a plan’s **next action** is done, write durable facts into [`product-state.md`](../../../docs/agents/product-state.md), [`decisions.md`](../../../docs/decisions.md), and relevant concept stubs. Link from the plan. **Do not move** plan files. Mark a plan leaf `deprecated` only if it would still read as current instructions.

## On write (defer detail)

Follow the global **`okf-docs`** seven-event checklist and producer on-write rules. When a concept changes in the same pass: refresh the folder’s index (e.g. [`docs/concepts/index.md`](../../../docs/concepts/index.md), [`docs/agents/index.md`](../../../docs/agents/index.md)) and prepend [`docs/log.md`](../../../docs/log.md) if the change is bundle-visible.
