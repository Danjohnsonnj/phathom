# Agent onboarding

Cold-start paths, efficiency rules, and environment bootstrap. **Always-on index:** [`AGENTS.md`](../../AGENTS.md).

---

## Context entry points

Do **not** scan all of `Phathom/`. Read the smallest set for the task:

| Task | Start here |
|------|------------|
| Decisions / invariants | [`docs/decisions.md`](../decisions.md) — index + matching rows |
| Domain terms | [`CONTEXT.md`](../../CONTEXT.md) — glossary only |
| RAG Chat roadmap | [`docs/handoff/phase-3-rag-chat.md`](../handoff/phase-3-rag-chat.md) |
| UI polish | [`docs/handoff/ui-design-refresh.md`](../handoff/ui-design-refresh.md) |
| Pipeline | [`BackgroundPipeline.swift`](../../Phathom/Phathom/Services/BackgroundPipeline.swift) |
| Inference | [`SharedLlamaInference.swift`](../../Phathom/Phathom/Services/SharedLlamaInference.swift) |
| UI shell | [`Views/`](../../Phathom/Phathom/Views/) — recall agentmemory **UI** topic; `MainTabView` → `LibraryTab` → `DetailView` → `AddNewTab`; Settings via Library gear |
| Historical specs | [`docs/archive/`](../archive/) — **opt-in only** |

Structural categories: **`PhathomCore.Category`**, **`LibraryCategoryFilterStorage`**, **`CategoryDisplayFormatter`**. UI binds SwiftData; schedules work via **`BackgroundPipeline`** and **`ProcessingRecovery`** — never calls Llama directly.

---

## Efficiency rules

1. **Implicit knowledge:** `import llama` C API available; don't ask for headers unless debugging a crash.
2. **Read code before docs:** Smallest `.swift` set first; then `decisions.md` / hand-offs; archive only after those fail — verify in code.
3. **Minimalist UI reads:** Relevant `View` + model only — not whole `App`.
4. **Session awareness:** **`SharedLlamaInference.withSession`** only; never parallel Llama calls.
5. **KV fast-path:** `llama_memory_seq_cp` — one article prefill for Summarize → Tags → Extracts; preserve in pipeline refactors.

---

## Environment bootstrap

- **README:** [`README.md`](../../README.md) — product overview for humans; build + Llama detail when needed.
- **xcframework:** `Phathom/vendor/llama/llama.xcframework` — if missing: `bash scripts/setup-llama-xcframework.sh`
- **Build:** `bash scripts/build-phathom.sh sim` (routine); `device` for signing; `all` for xcframework refresh / pre-release only. iPhone **16 Pro+** sim or device. `EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64` for arm64-only xcframework.
- **Tests:** `bash scripts/test-phathom.sh` (`--grep`, `--test`, `--list`; skips UITests).
- **Simulator:** CPU-only Llama; don't optimize for GPU/ANE unless on device.
- **GGUF:** Security-scoped bookmarks — see README Llama section.
- **New session:** Say **"Read and ready"** once oriented. If agentmemory MCP is down, user gets one clear notice — see [`agentmemory.md`](agentmemory.md#when-mcp-is-unavailable) (not a blocker).

---

## Active scope

Pipeline + ingest **shipped**. Roadmap: **RAG Chat** ([`phase-3-rag-chat.md`](../handoff/phase-3-rag-chat.md)), **UI polish** ([`ui-design-refresh.md`](../handoff/ui-design-refresh.md)). **Do not** implement RAG or expand Chat unless explicitly directed.

---

## Verification

Follow **[`.cursor/rules/simulator-verify.mdc`](../../.cursor/rules/simulator-verify.mdc)** (request when verifying Swift). Summary:

1. **ReadLints** on touched Swift
2. **`bash scripts/build-phathom.sh sim`** (incremental)
3. **Warnings grep** on touched `.swift` when pre-merge or inference/pipeline paths — cap ~40 lines
4. **`bash scripts/test-phathom.sh --test`** / **`--grep`** for behavioral fixes; full suite before merge
5. Never paste full build/test logs — failure snippets only

**Shortcuts:** small fix → ReadLints → sim build; behavioral → + targeted test; pre-merge → sim + warnings policy + full tests.

---

## Pre-merge checklist

- [ ] SwiftData changes: migration plan or Clear Library debug path
- [ ] Inference lifecycle changes: row in `docs/decisions.md`
- [ ] New ingest paths: `sourceMarkdown` fallback
- [ ] Plan mode: ask user when multiple valid approaches
- [ ] Landed changes: ReadLints + sim build; warning grep when policy applies (see verify rule)
