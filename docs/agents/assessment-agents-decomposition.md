# Assessment: `AGENTS.md` decomposition (Phase 4)

_Date: 2026-05-30. Status: **complete — Outcome C**._

## Industry consensus (web research, May 2026)

Sources: [agents.md](https://agents.md/), [Cursor rules docs](https://cursor.com/docs/rules), [CLAUDE/AGENTS guide](https://tianpan.co/blog/2026-02-25-claude-md-agents-md-ai-coding-agent-instruction-files), [DEV: not a junk drawer](https://dev.to/tacoda/agentsmd-is-not-a-junk-drawer-429j), [mattpocock setup skill](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md).

| Practice | Consensus | Phathom today |
|----------|-----------|---------------|
| **README vs AGENTS** | README = humans; AGENTS = agent ops (build, test, boundaries). Complement, don't duplicate product prose. | Partial overlap (build, Llama) — README human, AGENTS repeats bootstrap |
| **Root file size** | Lean root: **~60–100 lines** high-signal (HumanLayer); **≤300** ceiling — above that use progressive disclosure (`agent_docs/`, `@imports`, nested AGENTS). Healthy file = **dozens of lines that change behavior**. | **~185 lines** — above lean target; agentmemory block ≈40% |
| **Progressive disclosure** | Task/domain detail in linked files; root = index + invariants + copy-paste commands. Monorepos: nested AGENTS.md. | Phase 3 added `CONTEXT.md`; Phase 1 added `docs/agents/*` — **same pattern should extend to onboarding/verify/agentmemory** |
| **`.cursor/rules` vs AGENTS** | **Don't duplicate.** `alwaysApply: true` sparingly (foundational only). Scoped/requestable rules for verify, style, domain. AGENTS = plain markdown index. | **Duplicate:** verify ladder (requestable rule + 15 lines in AGENTS) |
| **What belongs in AGENTS** | Non-inferable: exact commands, never-do boundaries, arch constraints agents get wrong. **Delete** lines where removal wouldn't change behavior. | UI paragraph + agentmemory templates + verify detail are candidates to move |
| **Matt Pocock pattern** | Thin `## Agent skills` block in AGENTS/CLAUDE — **one-liner per topic → `docs/agents/*.md`**. | ✅ Done (issue tracker, triage, domain, cheatsheet) |
| **Treat as code** | PR-review AGENTS changes; prune to prevent context rot. | Matches Phase 4 goal |

**Research-backed default for Phathom:** **Outcome C** — lean always-on AGENTS (~50–80 lines) + split playbooks under `docs/agents/`; drop duplicated verify body; verify canonical in `simulator-verify.mdc`.

---

## Executive summary

**`AGENTS.md`** is ~185 lines and loaded as a workspace rule on every agent session. After Phase 3, **`CONTEXT.md`** and **`docs/agents/domain.md`** own glossary + skill consumer rules — but **`AGENTS.md`** still carries substantial overlap with README, requestable **`.cursor/rules/simulator-verify.mdc`**, and its own **`docs/agents/*`** pointers.

**No rewrite until you pick an outcome below.**

---

## Current inventory

| Section | Lines (approx) | Always-on? | Overlap / notes |
|---------|----------------|------------|-----------------|
| System Role & Identity | ~7 | Yes | Unique — agent persona |
| Tech Stack | ~5 | Yes | Partial overlap README major functionality table |
| Source of truth | ~12 | Yes | Overlaps `CONTEXT.md`, `domain.md`; **needed** as single index |
| Context Entry Points | ~12 | Yes | UI shell paragraph duplicates agentmemory topic table + `CONTEXT.md` anchors |
| Efficiency Rules | ~7 | Yes | **Must-keep** — `withSession`, KV reuse, minimal read |
| Getting Up to Speed | ~16 | Yes | Overlaps README build/requirements |
| Verification ladder | ~15 | Yes | **~80% duplicate** of `simulator-verify.mdc` (requestable, not alwaysApply) |
| Agent skills | ~18 | Yes | Thin pointers — **keep** (Phase 1 investment) |
| Agentmemory | ~75 | Yes | Largest block: obligations, 12-row topic table, phrase map, 6 session templates, save/skip |
| PR & Development Checklist | ~7 | Yes | Partial overlap verification ladder + plan-mode user rules |

**Related files**

| File | Lines | Role |
|------|-------|------|
| `README.md` | ~109 | Human onboarding, product, build, Llama perf |
| `.cursor/rules/simulator-verify.mdc` | ~49 | on-demand — full verify policy |
| `docs/agents/domain.md` | ~50 | Skill domain consumer rules |
| `CONTEXT.md` | ~90 | Glossary (Phase 3) |

**Estimated always-on token load:** ~2.5–4k tokens for full `AGENTS.md` (varies by host). Agentmemory section alone ≈ 40% of file.

---

## Category 1 — Cold-start token budget

**Tension:** Every line in `AGENTS.md` competes with code + task context in the context window.

| Approach | Token impact | Risk |
|----------|--------------|------|
| **Keep full file** | Highest | Agents may skim less; redundant verify text burns budget |
| **Trim in place** (~80–100 lines) | Medium savings (~30–40%) | Must not drop `withSession`, source-of-truth order, scope guardrails |
| **Split + lean `AGENTS.md`** (~40–60 lines) | Largest savings | Agents must follow pointers; cold agents might miss split files unless linked clearly |
| **Defer** | None | Status quo; Phase 3 glossary already helped issue skills |

**Progressive context lens:** Phathom already moved *names* to `CONTEXT.md` and *skills* to `docs/agents/`. Natural next extractions: **verification** and **agentmemory playbooks**.

---

## Category 2 — Always-on vs on-demand

What **must** load every session vs pull when relevant?

| Content | Recommendation if splitting |
|---------|----------------------------|
| Role, stack, source-of-truth table | **Always-on** |
| `withSession`, no parallel LLM, no RAG unless directed | **Always-on** (invariants) |
| UI shell file map (long paragraph) | **On-demand** → `docs/agents/onboarding.md` or agentmemory UI topic |
| Verification ladder (15 lines) | **On-demand** → pointer to `simulator-verify.mdc` only |
| Agentmemory topic table + templates | **On-demand** → `docs/agents/agentmemory.md` |
| PR checklist | **On-demand** or trim to 3 bullets + pointer |
| Agent skills block | **Always-on** (short) |

---

## Category 3 — Audience (human vs agent)

| File | Primary audience | Overlap |
|------|------------------|---------|
| `README.md` | Humans (+ “read first” for agents) | Build, Llama setup, product — agents told to read README in AGENTS |
| `AGENTS.md` | Agents | Should not re-teach human-oriented Llama QA steps |
| `CONTEXT.md` | Agents + issue skills | Terms only |
| `.cursor/rules/*` | Agents (Cursor injection) | Verify policies |

**Productivity trade-off:** One **`AGENTS.md`** is discoverable. Split files need a **table of pointers** at top so humans editing repo know where to add rules.

---

## Category 4 — Duplication with `.cursor/rules/`

| Duplication | Resolution options |
|-------------|-------------------|
| Verification ladder vs `simulator-verify.mdc` | **Replace AGENTS body with 2-line pointer** to rule + `scripts/build-phathom.sh` |
| Plan-mode / PR checklist vs user rules | Keep minimal invariant bullets in AGENTS; detailed plan workflow stays in Cursor user rules |

**Rule of thumb:** **Canonical verify policy = `simulator-verify.mdc`**. AGENTS mentions it once; no third copy in a split file unless humans need offline read.

---

## Category 5 — Must-keep invariants (non-negotiable)

These must survive any outcome:

1. **`SharedLlamaInference.withSession`** — serialized inference; no parallel Llama
2. **Source-of-truth order** — code → CONTEXT → decisions → hand-offs → README; archive opt-in
3. **Scope guardrail** — do not implement RAG / expand Chat unless directed
4. **Agent skills pointers** — `docs/agents/issue-tracker`, triage-labels, domain, cheatsheet
5. **Agentmemory authority** — memory never overrides decisions or code
6. **Verification exists** — even if only a pointer to `simulator-verify.mdc`

---

## Outcome options

| ID | Name | What changes | Est. AGENTS size |
|----|------|--------------|------------------|
| **A** | **Defer** | No structural change; optional tiny fixes (broken links) | ~185 lines |
| **B** | **Trim in place** | Shorten verify to pointer; compress UI paragraph; keep agentmemory inline | ~110–130 lines |
| **C** | **Split files** | Lean `AGENTS.md` + `docs/agents/onboarding.md` + `docs/agents/agentmemory.md`; verify = pointer to rule only | ~50–65 lines always-on |
| **D** | **Aggressive split** | Same as C + move PR checklist to `docs/agents/checklist.md`; README cross-link “agents start here” | ~40–50 lines always-on |

**Agent lean recommendation:** **C** — aligns with agents.md spec, Cursor rules docs, and mpocock `docs/agents/` pattern. **B** only if you reject split files on principle.

**Research already decides (no interview needed):**

- Replace verify ladder body with 2-line pointer → `simulator-verify.mdc` canonical
- Don't duplicate README product/Llama essays in AGENTS → pointer to README for human-oriented detail
- Keep thin **Agent skills** block + source-of-truth table always-on

---

## Interview record

| Field | Value |
|-------|-------|
| Research pass | 2026-05-30 — agents.md, Cursor docs, progressive disclosure consensus |
| Chosen outcome | **C** — lean AGENTS + `onboarding.md` + `agentmemory.md` (2026-05-30) |
| Agentmemory in AGENTS | One-liner + link to `docs/agents/agentmemory.md` |
| README | Added “For agents → AGENTS.md” + CONTEXT link |
| Post-split AGENTS size | ~65 lines (was ~185) |

**`AGENTS.md` (always-on)**

- Role + stack (5 lines)
- Source-of-truth table + conflict resolution
- Hard invariants (withSession, scope, archive)
- Agent skills pointers (existing block)
- “Read next” links: onboarding, agentmemory, simulator-verify rule

**`docs/agents/onboarding.md` (on-demand)**

- Context entry points (file paths)
- Efficiency rules
- Environment bootstrap (xcframework, sim target)
- Active roadmap one-liner

**`docs/agents/agentmemory.md` (on-demand)**

- Obligations, topic table, phrase → action, session templates, save/skip

---

## Proposed split sketch (Outcome C/D — research-aligned)