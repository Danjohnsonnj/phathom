# Agentmemory playbook

Long-term context via **agentmemory** MCP. **Authority:** code > `docs/decisions.md` > hand-offs > memory.

Recall at session start for the task domain; save after architectural decisions, perf fixes, and non-obvious constraints.

---

## Obligations

1. **Session start:** Check whether **agentmemory** MCP is installed and responding. **Probe:** server **`user-agentmemory`**, tool **`memory_recall`** — read the tool schema under `mcps/user-agentmemory/tools/` (or list tools) before calling; do **not** guess names like `search_memories`. A **tool-not-found** error means the wrong tool name, **not** that the server is unavailable. Lightweight probe: `memory_recall` with a short query (e.g. task domain), `limit: 1`, `format: compact`. If **available** → recall for the task domain before broad file reads; announce per host rules if required. If **unavailable** → notify the user once (see below); **do not treat as failure** — continue with repo docs and code.
2. **Authority:** Memory is a gist — never overrides decisions or Swift sources. Read full `docs/decisions.md` for cross-cutting inference/schema/backup edge cases.
3. **Save after:** final architectural choices, perf root-causes, must-not constraints — **only when MCP is available**.
4. **Format:** bullets tagged with concepts (`pipeline`, `KV-cache`, `decisions`); not pasted doc paragraphs.

---

## When MCP is unavailable

Phathom does **not** require agentmemory. Agents should still cold-start from **`AGENTS.md`**, **`CONTEXT.md`**, **`docs/decisions.md`**, and Swift sources.

**Once per session**, if MCP is missing, disabled, or unresponsive, tell the user plainly (adapt wording; keep it short):

> **Agentmemory MCP is not available** in this session (not installed, disabled, or not responding). That is **OK** — I can still work from repo docs and code. Cross-session recall and automatic memory saves are off until you enable the **agentmemory** MCP in Cursor. Say if you want setup help; otherwise I'll continue without it.

**Do not:** block the task, apologize repeatedly, or retry MCP on every turn. **Do:** mention again only if the user asks about memory or says they enabled MCP mid-session.

---

## Topic memories (what to recall)

| Domain | Recall concepts | Code/doc anchors |
|--------|-----------------|------------------|
| Pipeline & inference | `pipeline`, `withSession`, `KV-cache` | `BackgroundPipeline.swift`, `SharedLlamaInference.swift`, `ModelManager.swift` |
| llama.cpp backend | `llama.cpp`, `xcframework`, `LlamaCppRuntime`, `Metal` | `Inference/LlamaCppRuntime.swift`, `vendor/llama/llama.xcframework` |
| Decisions gist | `decisions`, `decisions.md`, `gist` | `docs/decisions.md` |
| Performance | `performance`, `thermal`, `PipelineMetrics` | README Llama perf, `[PhathomPipeline]` logs |
| Schema | `ContentItem`, **`Category`**, `processingStatus` | `PhathomCore/` |
| UI shell & pipeline bridge | `UI`, `LibraryTab`, `DetailView`, `CategoryPicker` | `Views/`, `ProcessingRecovery.swift`, `LibrarySearchService.swift` |
| **UI evolution (shipped May 2026)** | `UI-evolution`, `AppSpacing`, `HairlineHighlightRow`, `EditorialScreenTitle`, `HairlineCapsuleButton` | **Invariants:** [`decisions.md`](../decisions.md) UI rows · **Tokens:** [`design-tokens.md`](../design-tokens.md) · **Reference (opt-in):** [`library-ui-evolution.md`](../archive/library-ui-evolution.md) §3 · [`design-mocks/README.md`](../archive/design-mocks/README.md) |
| **UI evolution — design probes (historical process)** | `design-mock-probe`, `HTML-probe`, `SwiftUI-target` | Skill [`design-mock-probe`](~/.cursor/skills/design-mock-probe/SKILL.md) + [`design-mock-probe-pointer.md`](design-mock-probe-pointer.md) — reference mode only post-rollout |
| UI design refresh (shipped v1) | `tokens`, `AppPalette`, `IA` | [`ui-design-refresh.md`](../archive/ui-design-refresh.md) — historical only |
| Bulk library select | batch archive undo | [`library-bulk-selection.md`](../archive/library-bulk-selection.md), `MainTabView` |
| Archived docs | `history` | [`archive/README.md`](../archive/README.md) — opt-in only |
| Scope | `Phase-3`, `no-RAG` | `phase-3-rag-chat.md` |
| Dev bootstrap | `build`, `xcframework`, `test` | `scripts/build-phathom.sh`, `scripts/test-phathom.sh` |
| App versioning | `version`, `semver`, `MARKETING_VERSION` | `project.pbxproj`, `SettingsTab.swift` |

---

## User phrase → agent action

| User says | Agent does |
|-----------|------------|
| "Recall agentmemory for …" | `memory_recall` / `memory_smart_search` |
| "Save to agentmemory …" | `memory_save` (right topic; short bullets) |
| "Update decisions memory" | Refresh decisions gist after `decisions.md` changes |
| "What's in memory about X?" | Search and summarize hits |

---

## Session templates (copy-paste)

**Cold start (implementation)**

> Resume Phathom. Recall pipeline, decisions, and performance memories. Task: [one sentence]. Read **Swift + `docs/decisions.md` first**; hand-offs second; archive only if required.

**Planning**

> Recall scope + decisions gist. I want to add [feature]. Say if Phase 3 or schema escalation. Plan only—no code. Save outcome to agentmemory when we decide.

**Perf / inference debug**

> Recall pipeline + llama.cpp + performance memories. Symptom: [e.g. analyze slow on device]. Use `[PhathomPipeline]` logs. Propose checks in order; save root cause to agentmemory when fixed.

**llama.cpp / xcframework**

> Recall llama.cpp backend memory. Task: [e.g. bump xcframework]. Read `LlamaCppRuntime.swift`; update memory if build path or context params change.

**After editing `docs/decisions.md`**

> I added a decision row for [topic]. Update agentmemory decisions gist RECENT to match.

**UI / library / detail**

> Recall Phathom UI architecture memory. Task: [one sentence]. Read only affected Views + pipeline hooks (`ProcessingRecovery`, `BackgroundPipeline`).

**UI evolution — reference (post-rollout)**

> Rollout complete May 2026 (Phases 0–4b). Cold-start UI from **`Phathom/`** + [`decisions.md`](../decisions.md) UI rows + [`design-tokens.md`](../design-tokens.md). Opt-in §3: [`library-ui-evolution.md`](../archive/library-ui-evolution.md). Archived HTML mocks: [`design-mocks/`](../archive/design-mocks/) (visual reference only).

---

## When to save vs skip

| Save | Skip |
|------|------|
| Final architectural choice | Brainstorm "maybe" ideas |
| Perf finding or fix pattern | Every file opened |
| New invariant / must-not | Full specs (use handoff/docs) |
| **UI discovery process** (workflow gist) | **Locked UI particulars** (use `docs/handoff/*.md`) |
| Decision row candidate | Implementation diffs (git) |

**Maintenance:** append `docs/decisions.md` first; then update agentmemory. xcframework / `LlamaCppRuntime` changes → refresh llama.cpp backend memory.
