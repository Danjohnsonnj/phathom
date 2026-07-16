# Process — how we work on this effort

Durable methodology. Read once per session before committing. Reached via AGENTS.md → HANDOFF.md.

**Adoption mode:** own-project

## Cold-start protocol

1. Read AGENTS.md (auto-loaded); it points here and to HANDOFF.md.
2. Read HANDOFF.md (always).
3. Load ONLY the leaves under HANDOFF.md "Required reading (this phase)".
4. Pull any other leaf from the Index on demand.

## Update discipline

- Briefs hold CURRENT truth: overwrite in place; correct mistakes directly.
- progress-log.md holds HISTORY: append-only dated entries; never rewritten.
- Single source of truth per fact: the next action lives only in HANDOFF.md.

## Session-handoff ritual (user-initiated wrap-up)

1. Overwrite affected brief(s) in place.
2. Refresh HANDOFF.md (phase, next action, required reading, open decisions, last-updated).
3. Append a dated progress-log.md entry (happened / learned / overwrote).
4. Fold reusable gotchas into lessons.md.
5. Commit per adoption mode, only when the user asks.

## Adoption mode: own-project

- Artifacts (`docs/_handoff/*`) are tracked and committed normally alongside code, only when the user asks.
