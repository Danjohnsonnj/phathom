---
type: TechBrief
title: "OKF alignment tech brief"
description: Verified doc layout, the stable frontmatter card, and the repo skill.
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:05:00Z" }
---

# Tech brief - current state and gaps

## Current architecture (verified)

- [`docs/index.md`](../../index.md) and [`docs/log.md`](../../log.md) — OKF bundle hub (Settled | In progress) and chronology; reserved files, no concept `type`.
- [`AGENTS.md`](../../../AGENTS.md) — trimmed cold-start: hard invariants, QA, tracker; hub + [`.cursor/skills/docs-maintenance/SKILL.md`](../../../.cursor/skills/docs-maintenance/SKILL.md).
- [`CONTEXT.md`](../../../CONTEXT.md) — pointer to [`docs/concepts/index.md`](../../concepts/index.md); glossary rows live under `docs/concepts/`.
- [`docs/concepts/`](../../concepts/index.md) — OKF v0.2 card on stubs: `resource` (not `anchor`), `status`, `generated`; [`with-session.md`](../../concepts/inference/with-session.md) and [`kv-cache-reuse.md`](../../concepts/inference/kv-cache-reuse.md) are **`type: Invariant`**.
- [`docs/decisions.md`](../../decisions.md) — `type: DecisionLog` frontmatter; append-only body unchanged.
- [`docs/design-tokens.md`](../../design-tokens.md) — `type: DesignTokens`, `resource` → `AppPalette.swift`.
- [`docs/agents/product-state.md`](../../agents/product-state.md) — `type: ProductState`; shipped/deferred snapshot.
- [`docs/handoff/`](../../handoff/index.md) — opt-in specs; YAML frontmatter **touch-later** (see disposition below); bodies not rewritten in this effort.
- [`docs/archive/`](../../archive/README.md) and [`docs/_handoff/`](../../_handoff/HANDOFF.md) — unchanged bodies; not in hub Settled.
- [`.cursor/rules/doc-hygiene.mdc`](../../../.cursor/rules/doc-hygiene.mdc) — attaches on `docs/**/*.md`; points at repo docs-maintenance skill.

## Verified findings / gaps

- **Done in this effort:** hub + log, glossary split, locked card on touched settled files, repo skill install, AGENTS trim, touch-later manifest, summary-progress promotion link to product-state.
- **Still touch-later:** handoff and listed agent guides (disposition section); no bulk frontmatter pass on those bodies.
- **Scan rule:** treat YAML frontmatter only when `---` is at byte 0 — many handoff/archive lines are horizontal rules.
- **New concept writes:** use ISO 8601 `generated.at` with zone; do not reintroduce `anchor` or `timestamp`.
- **Open plan trees:** `docs/plans/*` stay WIP paths; promote facts into settled docs without moving plan files.

## Proposed frontmatter card

OKF requires only `type`. Phathom requires the rows marked required on every **new or touched** concept. Reserved `index.md` and `log.md` get no `type`. Only the bundle-root index may set `okf_version: "0.2"`.

The three extensions come from columns the current docs already maintain, not from the spec:

| Extension | Where it already lives | Rule |
| --------- | ---------------------- | ---- |
| `resource` | Concept `anchor`; CONTEXT “Anchor” column; design-tokens code paths | One repo-relative path to the primary Swift file. Replaces `anchor`. Extra files stay as body links. |
| `aliases` | CONTEXT intro (“do not invent synonyms”); rows such as Extracts ← “key figures” | Short list, only when a real synonym exists. Omit the key when there is none. |
| `sources` | CONTEXT “Anchor” decision links; v0.2 provenance | The decision row that locks the term. `id` is a stable footnote label. Omit when no decision owns it. |

Hard invariants that are today `type: Glossary` plus tag `invariant` (`withSession`, KV cache reuse) become `type: Invariant`. Feature shipped/deferred stays in `product-state.md`, not a per-file key, so the two cannot drift.

```yaml
---
type: Invariant                # required; folder allow-list
title: withSession             # required here (OKF: optional)
description: One sentence.     # required here (OKF: optional)
status: stable                 # required here; draft | stable | deprecated
generated:                     # required here
  by: cursor-agent             # cursor-agent | human:<id> | process:<id>
  at: 2026-10-17T16:30:00Z     # ISO 8601 with zone
tags: [inference, pipeline]    # optional
resource: Phathom/Phathom/Services/SharedLlamaInference.swift
aliases: []                    # omit the key when empty
sources:                       # omit when no decision locks the term
  - id: decision-2026-05-02
    resource: docs/decisions.md
    title: Serialized session
verified:                      # set when a human locks a decision or invariant
  by: human:dan
  at: 2026-10-17T16:30:00Z
stale_after: 2027-04-17T00:00:00Z   # optional
---
```

Absent `status` means `stable` (v0.2). Consumers must tolerate unknown keys. Do not add `layer`, `timestamp`, `anchor`, a product-shipped flag, or a second code-path list. A single `verified` mapping is allowed; consumers treat it as a one-element list.

`docs/design-tokens.md` uses the same card with `type: DesignTokens`, `resource` pointing at `AppPalette.swift`, and a body link to `AppSpacing.swift`. Discoverability is the hub link, not an extra field.

Trust is advisory: no `verified` means unverified; only non-human actors means machine-confirmed; a `human:` actor means human-reviewed. Do not overwrite a `human:` `verified` concept without an explicit re-verify. Update `generated` on every rewrite.

### Folder allow-list

| Path | Allowed `type` | Notes |
| ---- | -------------- | ----- |
| `docs/concepts/` | `Glossary`, `Invariant`, `Module`, `Architecture`, `Lesson` | Existing stubs stay put |
| `docs/agents/` | `AgentGuide`, `ProductState` | Assessments get frontmatter on touch |
| `docs/runbooks/` | `Runbook`, `Playbook` | Create the folder index only when the first runbook is real |
| `docs/decisions.md` | `DecisionLog` | One file |
| `docs/design-tokens.md` | `DesignTokens` | Phathom extension; declare in the repo skill |
| `docs/handoff/` | `Handoff`, `DeliveryLog` | Phathom extension; on touch |
| `docs/plans/<slug>/` | plan-build leaf types | WIP. `HANDOFF.md` may be `status: stable` while the folder is still in progress |
| `docs/archive/` | none | Not in the Settled index. No frontmatter pass |

Plan leaf types stay as plan-build defines them: `Handoff`, `ProductBrief`, `TechBrief`, `Phases`, `Process`, `DeliveryLog` (`log.md` has no frontmatter; the type name is for the effort’s lessons/history leaves that are concepts), `Lesson`. `log.md` itself stays a reserved chronology with no frontmatter.

## Proposed skill

Repo overlay: [`.cursor/skills/docs-maintenance/SKILL.md`](../../../.cursor/skills/docs-maintenance/SKILL.md). It defers protocol (seven-event checklist, routing, on-write) to the global **`okf-docs`** skill and holds only Phathom exceptions:

- Authority: code > `docs/decisions.md` > active handoff / plan next action > concept stubs > `README.md`. `CONTEXT.md` is a pointer. Agentmemory never overrides code or decisions.
- The frontmatter card and allow-list above.
- Migration exceptions: `docs/archive/**` frozen; `docs/_handoff/` left until that effort wraps; open `docs/plans/` stay WIP.
- Promotion: when a plan’s next action is done, write durable facts into `product-state.md`, `decisions.md`, and concept stubs. Link from the plan. Do not move the plan files.

Wire-up (shipped): `AGENTS.md` Docs section + `doc-hygiene.mdc` on `docs/**/*.md` pointing at the repo skill (product-state first, refresh indexes + `docs/log.md` on concept touch).

## Folder map (no moves)

```text
Proposed adds: docs/index.md, docs/log.md, .cursor/skills/docs-maintenance/. Moves: none.

Before
├── AGENTS.md                      fat cold-start
├── README.md                      human landing
├── CONTEXT.md                     glossary monolith
└── docs/                          ← no index.md, no log.md
    ├── decisions.md
    ├── design-tokens.md
    ├── concepts/ …existing…
    ├── agents/ …existing…
    ├── handoff/ …existing…
    ├── archive/ …existing…        frozen
    ├── plans/summary-progress/
    └── _handoff/                  legacy plan

After
├── AGENTS.md                      [~] short always-on + hub link
├── README.md                      [~] optional docs subsection; stay human
├── CONTEXT.md                     [~] pointer to concepts/index.md
└── docs/
    ├── index.md                   [+] Settled | In progress
    ├── log.md                     [+]
    ├── decisions.md               [=] add frontmatter when touched
    ├── design-tokens.md           [=] type DesignTokens when touched
    ├── concepts/                  [=]
    ├── agents/                    [=]
    ├── handoff/                   [?] extra settled; on touch
    ├── archive/                   [=] outside Settled
    ├── plans/okf-alignment/       [+] this effort
    ├── plans/summary-progress/    [=]
    └── _handoff/                  [=] until that effort wraps
```

## Hard invariants

- Code wins. Do not “correct” code from a doc.
- Do not rewrite `docs/archive/**` bodies.
- Do not move a file to settle it.
- Do not split `docs/decisions.md`. After the glossary split, `CONTEXT.md` is a pointer only.
- `generated.at` is ISO 8601 with a zone.

## Touch-later disposition

**Do not edit these bodies in the OKF alignment effort.** Apply frontmatter only when a file is next touched for its own work. Reserved **`index.md`** files get no `type`.

### Handoff (`docs/handoff/`)

| Path | On touch |
| ---- | -------- |
| `docs/handoff/index.md` | Reserved index — no `type` |
| `docs/handoff/focus-stack.md` | `type: Handoff` |
| `docs/handoff/phase-3-rag-chat.md` | `type: Handoff` |
| `docs/handoff/focus-stack-delivery.md` | `type: DeliveryLog` |
| `docs/handoff/focus-stack-implementation.md` | `type: DeliveryLog` |
| `docs/handoff/macos-v1-delivery.md` | `type: DeliveryLog` |
| `docs/handoff/macos-spike-results.md` | `type: DeliveryLog` |

### Agents (`docs/agents/`)

All **`type: AgentGuide`** on touch. Historical assessments use **`status: deprecated`** when touched.

| Path | Notes |
| ---- | ----- |
| `docs/agents/agentmemory.md` | AgentGuide |
| `docs/agents/issue-tracker.md` | AgentGuide |
| `docs/agents/triage-labels.md` | AgentGuide |
| `docs/agents/skills-cheatsheet.md` | AgentGuide |
| `docs/agents/design-mock-probe-pointer.md` | AgentGuide |
| `docs/agents/assessment-doc-migration.md` | AgentGuide; deprecated when touched |
| `docs/agents/assessment-agents-decomposition.md` | AgentGuide; deprecated when touched |

**Not in this manifest (already typed in Phases 3–4):** `docs/design-tokens.md`, `docs/agents/doc-structure.md`, `docs/agents/domain.md`, `docs/agents/onboarding.md`, `docs/agents/product-state.md`.
