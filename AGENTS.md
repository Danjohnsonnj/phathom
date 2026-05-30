# Phathom: Agent Context & Efficiency Map

## System Role & Identity

Expert iOS engineer: local-first systems, on-device LLM, Metal-accelerated performance, privacy-first.

## Tech Stack

Swift 6 (strict concurrency) · SwiftData (local-only) · `llama.cpp` via `llama.xcframework` · serialized pipeline (Scrape → Embed → Analyze)

## Source of truth

Read **minimal files per task:**

| Priority | Source | Purpose |
|:--------:|--------|---------|
| 1 | **`Phathom/`** | Shipped behavior, schema, Swift paths |
| 2 | **[`CONTEXT.md`](CONTEXT.md)** | Domain glossary (names); links to decisions |
| 3 | **[`docs/decisions.md`](docs/decisions.md)** | Invariants and rationale |
| 4 | **Active hand-offs** | [`phase-3-rag-chat.md`](docs/handoff/phase-3-rag-chat.md), [`ui-design-refresh.md`](docs/handoff/ui-design-refresh.md), [`notebook-tab.md`](docs/handoff/notebook-tab.md) (Notebook MVP — **ready to build**) |
| 5 | **[`README.md`](README.md)** | Human orientation |

**Archive:** [`docs/archive/`](docs/archive/) — opt-in only; not for cold start.

**Conflict resolution:** Code > all prose. `decisions.md` > hand-offs > README. `CONTEXT.md` is glossary only. Agentmemory never overrides decisions or code.

## Hard invariants

- **`SharedLlamaInference.withSession`** — serialized inference; **no parallel Llama calls**
- **KV reuse** — maintain `llama_memory_seq_cp` summarize → tags → extracts path in pipeline refactors
- **Scope** — do **not** implement RAG / expand Chat tab unless explicitly directed
- **Response style** — see [`.cursor/rules/caveman.mdc`](.cursor/rules/caveman.mdc) (always applied)

## Agent skills

### Issue tracker

GitHub `Danjohnsonnj/phathom`; use `gh`. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

Seven labels: `bug` / `enhancement` + five state labels. See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

`Phathom/` → `CONTEXT.md` → `decisions.md` → hand-offs. See [`docs/agents/domain.md`](docs/agents/domain.md).

### Skills cheat sheet

Slash vs ask; pipeline order. See [`docs/agents/skills-cheatsheet.md`](docs/agents/skills-cheatsheet.md).

## Agentmemory

Optional **agentmemory** MCP for cross-session recall — **not required** to work in this repo (`docs/decisions.md`, `CONTEXT.md`, and code are sufficient).

- **Session start:** Probe MCP (e.g. list tools on `user-agentmemory`). If available → recall task domain silently; say **"Using agent memory MCP."** once if your host rules require it.
- **If unavailable or errors:** Tell the user **once per session** — not a blocker; repo docs are authoritative. Use the notice in [`docs/agents/agentmemory.md`](docs/agents/agentmemory.md#when-mcp-is-unavailable). Then proceed without retrying unless the user asks.
- **Playbook:** [`docs/agents/agentmemory.md`](docs/agents/agentmemory.md)

## Read next (on demand)

| Topic | Doc |
|-------|-----|
| Cold start, file paths, verify ladder | [`docs/agents/onboarding.md`](docs/agents/onboarding.md) |
| Verify policy (canonical) | [`.cursor/rules/simulator-verify.mdc`](.cursor/rules/simulator-verify.mdc) |
| Doc migration assessment | [`docs/agents/assessment-doc-migration.md`](docs/agents/assessment-doc-migration.md) |
