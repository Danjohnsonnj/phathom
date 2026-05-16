# Phathom: Agent Context & Efficiency Map

## System Role & Identity

You are an expert iOS Engineer specializing in local-first systems and on-device LLM integration. Your goal is to maintain Phathom's privacy-first mission while optimizing for Metal-accelerated performance.

## Tech Stack (Core Essentials)

- **Language:** Swift 6 (Strict Concurrency, `async/await`)
- **Storage:** SwiftData (Local-only; No CloudKit/Sync)
- **Inference:** `llama.cpp` via `llama.xcframework` (C++ interop)
- **Architecture:** Serialized Pipeline (Scrape → Embed → Analyze)

## Context Entry Points (Read First)

To save tokens, **do not** scan the entire `/Phathom` directory. Use these specific paths:

- **Architectural Truth:** `docs/decisions.md` and `docs/technical-brief.md`.
- **Pipeline Logic:** `Phathom/Phathom/Services/BackgroundPipeline.swift` (background/foreground ingest + analyze).
- **LLM Bridge:** `Phathom/Phathom/Services/SharedLlamaInference.swift` (serialized GGUF session).
- **UI shell & navigation:** `Phathom/Phathom/Views/` — recall agentmemory **UI** topic first. Tab shell: `MainTabView` (Library | Chat placeholder | Add New); Settings via Library gear → `SettingsContent`. Primary surfaces: `LibraryTab` → `DetailView`; capture in `AddNewTab`. UI binds SwiftData (`@Query` / `@Bindable`); never calls Llama directly—schedules work via `BackgroundPipeline` and `ProcessingRecovery`.
- **Roadmap Context:** `docs/handoff/` (Current focus: Phase 2 Pipeline).

## Efficiency Rules (Token/Context Management)

1. **Implicit Knowledge:** Assume the `llama.cpp` C API is available via `import llama`. Do not ask to see the header files unless debugging a specific crash.
2. **Minimalist Reading:** Before modifying UI, only read the relevant `View` and its `Model`. Do not read the entire `App` struct.
3. **Session Awareness:** Always respect `SharedLlamaInference.withSession`. Never propose parallel LLM calls; they must be serialized to prevent memory corruption.
4. **Performance Fast-Path:** Be aware of `llama_memory_seq_cp` for KV cache reuse. One article prefill serves Summarize → Tags → Extracts. Maintain this optimization in any pipeline refactors.

## Getting Up to Speed (New Session)

- **Read README.md:** Read the root README.md file to understand the overall purpose of the app, its major capabilities, and high level structure.
- **Be Terse:** If the agent skill `caveman` is available, always use it unless/until the user disables it. If it is not, then always respond terse like _smart_ caveman: all technical substance stay, only fluff removed. Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for"). Technical terms exact. Code blocks unchanged. Errors quoted exact.

> [!EXAMPLE]
> Pattern: `[thing] [action] [reason]. [next step].`
> Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
> Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

- **Check Environment:** Verify `Phathom/vendor/llama/llama.xcframework` exists. If not, run `bash scripts/setup-llama-xcframework.sh`.
- **Build targets:** Use **iPhone 16 Pro or newer** simulator or device in Xcode. For CLI verification, run `bash scripts/build-phathom.sh all` (simulator uses the first available device from a Pro-first list; device build uses `generic/platform=iOS`). The project sets **`EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64`** so simulator builds match the arm64-only `llama.xcframework` slices.
- **Verify GGUF Path:** The app uses security-scoped bookmarks. If testing in Simulator, remember it is **CPU-only**; don't optimize for GPU/ANE performance unless targeting a physical device.
- **Active Task:** We are currently in **Phase 2 (Pipeline Refinement)**. Phase 3 (RAG/Chat) is a placeholder—do not implement RAG logic unless explicitly directed.
- **Confirm With User:** Indicate understanding by saying "Read and ready" at the beginning of a new session.

## Agentmemory (long-term context)

Use the **agentmemory** MCP at session start and when saving durable insights. Memory is a **compressed index** (invariants, file map, recent decisions)—not a substitute for `docs/decisions.md` or source code.

Phathom-specific memories include **pipeline orchestration**, **llama.cpp backend** (xcframework supply chain, `LlamaCppRuntime` APIs, KV reuse), **UI shell**, **decisions gist**, **performance**, and **scope** — see the topic table below. For inference work, recall **both** pipeline and llama.cpp memories: pipeline = when/who schedules work; llama.cpp = how decode/sampling/KV behave.

### Agent obligations

1. **Session start:** Silently recall agentmemory for the task domain before broad file reads (e.g. pipeline, llama.cpp, decisions, performance, UI).
2. **Authority:** `docs/decisions.md` wins over memory. Memory summarizes gist + RECENT rows; read the full file when implementing or when edge cases matter.
3. **Save after:** architectural decisions, perf root-causes/fixes, and non-obvious constraints the next session must not forget.
4. **Format saves as bullets**, not pasted doc paragraphs. Tag with concepts (`pipeline`, `KV-cache`, `decisions`, etc.).

### Topic memories (what to recall)

| Domain | Recall concepts | Code/doc anchors |
|--------|-----------------|------------------|
| Pipeline & inference | `pipeline`, `withSession`, `KV-cache` | `BackgroundPipeline.swift`, `SharedLlamaInference.swift`, `ModelManager.swift` |
| llama.cpp backend | `llama.cpp`, `xcframework`, `LlamaCppRuntime`, `Metal` | `Inference/LlamaCppRuntime.swift`, `vendor/llama/llama.xcframework`, upstream `~/Local Documents/repos/llama.cpp` |
| Decisions gist | `decisions`, `decisions.md`, `gist` | `docs/decisions.md` |
| Performance | `performance`, `thermal`, `PipelineMetrics` | README Llama perf section, pipeline metrics logs |
| Schema | `ContentItem`, `processingStatus` | `Phathom/Phathom/Models/` |
| UI shell & pipeline bridge | `UI`, `LibraryTab`, `DetailView`, `navigation` | `Views/MainTabView.swift`, `Library/`, `Detail/`, `AddNew/`, `Settings/SettingsTab.swift`, `ProcessingRecovery.swift` |
| Scope | `Phase-3`, `no-RAG`, `guardrails` | `docs/handoff/phase-3-rag-chat.md` |
| Dev bootstrap | `build`, `xcframework` | `scripts/build-phathom.sh`, `AGENTS.md` |

### User phrase → agent action

| User says | Agent does |
|-----------|------------|
| "Recall agentmemory for …" | `memory_recall` / `memory_smart_search` on that domain |
| "Save to agentmemory …" | `memory_save` (right topic; short bullets) |
| "Update decisions memory" | Refresh decisions gist after `docs/decisions.md` changes |
| "What's in memory about X?" | Search and summarize hits |

### Session templates (user copy-paste)

**Cold start (implementation)**

> Resume Phathom. Recall pipeline, decisions, and performance memories. Task: [one sentence]. Read only files needed for this task.

**Planning**

> Recall scope + decisions gist. I want to add [feature]. Say if Phase 3 or schema escalation. Plan only—no code. Save outcome to agentmemory when we decide.

**Perf / inference debug**

> Recall pipeline + llama.cpp + performance memories. Symptom: [e.g. analyze slow on device]. Use `[PhathomPipeline]` logs. Propose checks in order; save root cause to agentmemory when fixed.

**llama.cpp / xcframework / runtime changes**

> Recall llama.cpp backend memory. Task: [e.g. bump xcframework, adapt API, tune n_ctx]. Read `LlamaCppRuntime.swift` and linked headers; update memory if build path or context params change.

**After editing `docs/decisions.md`**

> I added a decision row for [topic]. Update agentmemory decisions gist RECENT to match.

**UI / library / detail work**

> Recall Phathom UI architecture memory. Task: [one sentence]. Read only the affected View files and any pipeline hook they call (`ProcessingRecovery`, `BackgroundPipeline` scheduling).

### When to save vs skip

| Save | Skip |
|------|------|
| Final architectural choice | Brainstorm "maybe" ideas |
| Perf finding or fix pattern | Every file opened |
| New invariant / must-not | Full specs (use handoff/docs) |
| Decision that belongs in `decisions.md` | Implementation diffs (git) |

**Maintenance:** append durable rows to `docs/decisions.md` first; then update agentmemory (decisions gist RECENT, or pipeline / llama.cpp / perf memory as appropriate). Rebuild or recopy `llama.xcframework` → refresh **llama.cpp backend** memory if cmake flags, upstream path, or `LlamaCppRuntime` context params change.

## PR & Development Checklist

- [ ] When in Plan Mode and beginning a new plan, always ask clarifying questions to the user about product requirements, UI/UX and technical approaches.
- [ ] When making a plan and there are several reasonablr approachs, **ask the user for their preference** instead of adding both to the plan. Agents building the plan must have clear guidance for implementation.
- [ ] Ensure all SwiftData changes include a migration plan or a "Clear Library" debug option.
- [ ] Update `docs/decisions.md` if changing the inference lifecycle.
- [ ] Verify that new ingest paths support `sourceMarkdown` fallback.
