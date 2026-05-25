# Archived documentation

**Agents: do not read files in this folder unless a narrow exception applies** — see **Source of truth** in [`AGENTS.md](../../AGENTS.md#source-of-truth). **Authoritative sources:** source code under `Phathom/`, [`docs/decisions.md`](../decisions.md), and active handoffs under [`docs/handoff/`](../handoff/).

Content here is **historical** (pre-build vision or completed phase specs). It **may contradict** shipped behavior.

| File | Summary | Known drift |
|------|---------|-------------|
| [`product-brief.md`](product-brief.md) | Original product vision (~May 2026) | Voice memos / multimodal vision / NLEmbedding not roadmap truth; platform string outdated |
| [`technical-brief.md`](technical-brief.md) | Early architecture sketch + patched “implemented” sections | Pseudocode schema; RAG stack (NLEmbedding, ObjectBox); BG task power flags vs `decisions.md` |
| [`phase-1-ui-shell.md`](phase-1-ui-shell.md) | Phase 1 agent hand-off (shipped UI shell) | Says iOS 26+; superseded by code + decisions |
| [`phase-2-pipeline.md`](phase-2-pipeline.md) | Phase 2 agent hand-off (pipeline + Llama) | File-map useful; cites historical RAG prose — use **code + decisions** first |
