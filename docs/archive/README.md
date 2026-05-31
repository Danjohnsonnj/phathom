# Archived documentation

**Agents: do not read files in this folder unless a narrow exception applies** — see **Source of truth** in [`AGENTS.md](../../AGENTS.md#source-of-truth). **Authoritative sources:** source code under `Phathom/`, [`docs/decisions.md`](../decisions.md), and active handoffs under [`docs/handoff/`](../handoff/).

Content here is **historical** (pre-build vision or completed phase specs). It **may contradict** shipped behavior.

| File | Summary | Known drift |
|------|---------|-------------|
| [`product-brief.md`](product-brief.md) | Original product vision (~May 2026) | Voice memos / multimodal vision / NLEmbedding not roadmap truth; platform string outdated |
| [`technical-brief.md`](technical-brief.md) | Early architecture sketch + patched “implemented” sections | Pseudocode schema; RAG stack (NLEmbedding, ObjectBox); BG task power flags vs `decisions.md` |
| [`phase-1-ui-shell.md`](phase-1-ui-shell.md) | Phase 1 agent hand-off (shipped UI shell) | Says iOS 26+; superseded by code + decisions |
| [`phase-2-pipeline.md`](phase-2-pipeline.md) | Phase 2 agent hand-off (pipeline + Llama) | File-map useful; cites historical RAG prose — use **code + decisions** first |
| [`phase-0-vision-spike.md`](phase-0-vision-spike.md) | Phase 0 DEBUG VLM spike harness (retired) | Spike Settings UI removed; production vision in **Vision model** + [`media-vision-v1-qa.md`](media-vision-v1-qa.md) |
| [`library-bulk-selection.md`](library-bulk-selection.md) | Library bulk select + batch archive undo (**shipped**) | Behavior in code + decisions row 2026-05-12; use **code + decisions** first |
| [`notebook-tab.md`](notebook-tab.md) | Notebook tab — cross-library highlight feed (**shipped**) | Behavior in code + decisions row 2026-05-30; use **code + decisions** first |
| [`ui-design-refresh.md`](ui-design-refresh.md) | UI design refresh brief (**shipped**) | Redesign on `main`; §12 design-system gate never completed — use **code + `AppPalette`** first |
| [`media-vision-v1-qa.md`](media-vision-v1-qa.md) | Media vision v1 device QA matrix (**shipped**) | Automated tests in CI; device matrix historical — use **code + decisions** first |
| [`library-ui-evolution.md`](library-ui-evolution.md) | App UI evolution — locked §3 per-surface decisions (**shipped** May 2026) | Invariants in **decisions.md** UI rows; use **code + decisions** first |
| [`../design-tokens.md`](../design-tokens.md) | Cross-surface tokens, material matrix, button shapes (**live** — moved from archive May 2026) | **`AppSpacing`** / **`AppPalette`** in code authoritative for values |
| [`ui-evolution-implementation-plan.md`](ui-evolution-implementation-plan.md) | UI evolution Phases 0–4b execution plan (**shipped**) | Historical phase checklists; **decisions.md** + code authoritative |
| [`design-mocks/`](design-mocks/) | Six canonical HTML/CSS Safari mocks (**shipped** reference) | **`Phathom/`** + **decisions.md** authoritative; prune folder when no longer needed |
