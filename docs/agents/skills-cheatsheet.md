# Agent skills cheat sheet

When to use a slash command vs plain English. All skills below are **user-slashable and agent-auto-invokable** unless marked user-only.

## Slash vs ask

| Want this | Slash | Or just say |
|-----------|-------|-------------|
| Stress-test a plan before writing it up | `/grill-me` | "Grill me on this plan" |
| HTML design probe (visual, not spec) | `/design-mock-probe` | "Show me a design for…", "mock up this option", "what would this look like" |
| Turn agreed context into a PRD issue | `/to-prd` | "Publish a PRD for this to GitHub" |
| Slice a PRD/plan into child issues | `/to-issues` | "Break this into vertical-slice issues" |
| Review or move issues through triage | `/triage` | "What needs triage?" / "Move #42 to ready-for-agent" |
| One-time repo setup (already done) | `/setup-matt-pocock-skills` | — **user-only**; agent won't auto-run |
| Big-picture code orientation | `/zoom-out` | — **user-only**; agent won't auto-run |

**Rule of thumb:** Slash when you want a named workflow and predictable steps. Plain English works when the intent is obvious—the agent should load the same skill from its description.

## Typical pipeline

```text
/grill-me  →  shared plan
/to-prd    →  one PRD issue (enhancement + ready-for-agent)
/to-issues →  agent proposes slices → you approve → child issues
/triage    →  agent recommends → you pick category + state
```

## Who drives what

| Skill | Agent alone | You required |
|-------|-------------|--------------|
| `grill-me` | Explores codebase when useful | Answers questions one at a time |
| `design-mock-probe` | Routes intent; grill on lock pass; packet → subagent; prune forks | Safari review; explore vs lock if unclear |
| `to-prd` | Explores repo, writes PRD, publishes issue | Module/test scope check (skill asks once) |
| `to-issues` | Drafts slice list | Approve granularity, deps, HITL/AFK before publish |
| `triage` | Reads issues, repro (bugs), recommends state | Confirm transitions; override anytime |

## Related (not in default pipeline)

- **`grill-with-docs`** — like `grill-me` but updates glossary/ADRs inline; not symlinked in Phathom; use `/grill-me` here unless you add it.
- **`design-mock-probe`** — symlinked [`.cursor/skills/design-mock-probe`](../../.cursor/skills/design-mock-probe) → global skill; Phathom paths in [`design-mock-probe-pointer.md`](design-mock-probe-pointer.md). Auto-invokes from visual/mock phrases; requires grill-me before canonical HTML.
- **`improve-codebase-architecture`**, **`zoom-out`**, **`diagnose`**, **`tdd`** — separate engineering skills; see global `~/.cursor/skills/`.

## Config this repo

Tracker, labels, domain read order: [`issue-tracker.md`](issue-tracker.md), [`triage-labels.md`](triage-labels.md), [`domain.md`](domain.md).
