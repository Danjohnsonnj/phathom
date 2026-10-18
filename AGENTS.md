# Phathom: Agent Context & Efficiency Map

## Docs

Hub: [`docs/index.md`](docs/index.md). When editing `docs/` or wrapping a session, follow [`.cursor/skills/docs-maintenance/SKILL.md`](.cursor/skills/docs-maintenance/SKILL.md).

**Conflict resolution:** Code wins. `decisions.md` beats hand-offs and plans. Glossary terms live in [`docs/concepts/index.md`](docs/concepts/index.md) (`CONTEXT.md` is a pointer). Agentmemory never overrides code or decisions.

## System Role & Identity

Expert iOS engineer: local-first systems, on-device LLM, Metal-accelerated performance, privacy-first.

## Tech Stack

Swift 6 (strict concurrency) · SwiftData (local-only) · `llama.cpp` via `llama.xcframework` · serialized pipeline (Scrape → Embed → Analyze)

**XCFramework:** produce or refresh via [`README.md`](README.md) (`scripts/rebuild-llama-xcframework-with-mtmd.sh`; optional `SOURCE_XCF` copy). The vendored engine is pinned to llama.cpp **b11719**; A19+ devices can use the Metal 4 GPU tensor path when the embedded kernels probe successfully. Runtime rules stay under [`docs/concepts/inference/`](docs/concepts/inference/index.md).

## Hard invariants

- **`SharedLlamaInference.withSession`** — serialized inference; **no parallel Llama calls** (detail: [`docs/concepts/inference/`](docs/concepts/inference/index.md))
- **KV reuse** — maintain `llama_memory_seq_cp` summarize → tags → extracts path in pipeline refactors
- **Scope** — **Focus Stack v1 shipped** (Phases A + B + **A+**). Do **not** implement open **RAG / Chat tab** unless explicitly directed. Optional follow-up: **Phase C** (Connect / Thread) — gates in [`focus-stack-delivery.md`](docs/handoff/focus-stack-delivery.md); **wrap-up** = update [`product-state.md`](docs/agents/product-state.md) + delivery log

### Issue tracker

GitHub `Danjohnsonnj/phathom`; use `gh`. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

Seven labels: `bug` / `enhancement` + five state labels. See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

`Phathom/` → [`docs/concepts/index.md`](docs/concepts/index.md) → `decisions.md` → hand-offs. See [`docs/agents/domain.md`](docs/agents/domain.md).

### Skills cheat sheet

Slash vs ask; pipeline order. See [`docs/agents/skills-cheatsheet.md`](docs/agents/skills-cheatsheet.md).

## Agentmemory

Optional cross-session recall — playbook and session-start **`memory_recall`** obligations: [`docs/agents/agentmemory.md`](docs/agents/agentmemory.md).

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

| Topic                                 | Doc                                                                                  |
| ------------------------------------- | ------------------------------------------------------------------------------------ |
| Cold start, file paths, verify ladder | [`docs/agents/onboarding.md`](docs/agents/onboarding.md)                             |
| Verify policy (canonical)             | [`.cursor/rules/simulator-verify.mdc`](.cursor/rules/simulator-verify.mdc)           |
| Doc migration assessment              | [`docs/agents/assessment-doc-migration.md`](docs/agents/assessment-doc-migration.md) |
| OKF conventions                       | [`docs/agents/doc-structure.md`](docs/agents/doc-structure.md)                       |
