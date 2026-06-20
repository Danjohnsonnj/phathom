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
| 2 | **[`docs/agents/product-state.md`](docs/agents/product-state.md)** | What shipped / deferred now (cold-start after this file) |
| 3 | **[`CONTEXT.md`](CONTEXT.md)** | Domain glossary (names); links to decisions |
| 4 | **[`docs/concepts/index.md`](docs/concepts/index.md)** | Term lookup; inference stubs (**links only**) |
| 5 | **[`docs/decisions.md`](docs/decisions.md)** | Invariants and rationale |
| 6 | **[`docs/design-tokens.md`](docs/design-tokens.md)** | Cross-surface spacing, palette, material, button matrix |
| 7 | **Hand-offs (opt-in)** | [`docs/handoff/index.md`](docs/handoff/index.md) — not default cold-start |
| — | **UI evolution reference (archived, opt-in)** | [`library-ui-evolution.md`](docs/archive/library-ui-evolution.md) (locked §3) · [`ui-evolution-implementation-plan.md`](docs/archive/ui-evolution-implementation-plan.md) · [`design-mocks/`](docs/archive/design-mocks/) — Phases **0–4b shipped**; invariants in [`decisions.md`](docs/decisions.md) UI rows |
| 8 | **[`README.md`](README.md)** | Human orientation |

**Archive:** [`docs/archive/`](docs/archive/) — opt-in only; not for cold start.

**Conflict resolution:** Code > all prose. `decisions.md` > hand-offs > README. `CONTEXT.md` is glossary only. Agentmemory never overrides decisions or code.

## Hard invariants

- **`SharedLlamaInference.withSession`** — serialized inference; **no parallel Llama calls** (detail: [`docs/concepts/inference/`](docs/concepts/inference/index.md))
- **KV reuse** — maintain `llama_memory_seq_cp` summarize → tags → extracts path in pipeline refactors
- **Scope** — **Focus Stack v1 shipped** (Phases A + B + **A+**). Do **not** implement open **RAG / Chat tab** unless explicitly directed. Optional follow-up: **Phase C** (Connect / Thread) — gates in [`focus-stack-delivery.md`](docs/handoff/focus-stack-delivery.md); **wrap-up** = update [`product-state.md`](docs/agents/product-state.md) + delivery log
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

- **Session start:** Probe MCP with **`memory_recall`** on server **`user-agentmemory`** (read tool schema first — see [`agentmemory.md`](docs/agents/agentmemory.md#obligations); tool-not-found ≠ unavailable). If available → recall task domain silently; say **"Using agent memory MCP."** once if your host rules require it.
- **If unavailable or errors:** Tell the user **once per session** — not a blocker; repo docs are authoritative. Use the notice in [`docs/agents/agentmemory.md`](docs/agents/agentmemory.md#when-mcp-is-unavailable). Then proceed without retrying unless the user asks.
- **Playbook:** [`docs/agents/agentmemory.md`](docs/agents/agentmemory.md)

## Manual QA

### Category filing (Detail)

Before release or after touching filing UI:

1. From **Detail**, move an item to **Filed** when the category sheet appears — confirm picker choice persists and library filter reflects category.
2. **Cancel** / swipe-dismiss the sheet without confirming — item should stay non-Filed until user completes filing (library + Detail consistent).
3. Rotate device while sheet visible — no orphan pending state; filing completes or dismisses cleanly.

### Detail media (View Photo)

After touching [`MediaPhotoViewer.swift`](Phathom/Phathom/Views/Detail/MediaPhotoViewer.swift), [`DetailView`](Phathom/Phathom/Views/Detail/DetailView.swift) presentation, or media image load helpers:

1. Library → media Detail → **View Photo** — image + **Done** immediately (no app-switcher nudge).
2. Pinch/double-tap zoom behaves like Photos (fit at min zoom; pan when zoomed in).
3. Repeat from **Notebook** or **Recently Deleted** Detail (smoke).

## Read next (on demand)

| Topic | Doc |
|-------|-----|
| Cold start, file paths, verify ladder | [`docs/agents/onboarding.md`](docs/agents/onboarding.md) |
| Verify policy (canonical) | [`.cursor/rules/simulator-verify.mdc`](.cursor/rules/simulator-verify.mdc) |
| Doc migration assessment | [`docs/agents/assessment-doc-migration.md`](docs/agents/assessment-doc-migration.md) |
| OKF-lite conventions | [`docs/agents/doc-structure.md`](docs/agents/doc-structure.md) |
