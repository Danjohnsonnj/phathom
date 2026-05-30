# Phathom: Agent Context & Efficiency Map

## System Role & Identity

You are an expert iOS Engineer specializing in local-first systems and on-device LLM integration. Your goal is to maintain Phathom's privacy-first mission while optimizing for Metal-accelerated performance.

## Tech Stack (Core Essentials)

- **Language:** Swift 6 (Strict Concurrency, `async/await`)
- **Storage:** SwiftData (Local-only; No CloudKit/Sync)
- **Inference:** `llama.cpp` via `llama.xcframework` (C++ interop)
- **Architecture:** Serialized Pipeline (Scrape → Embed → Analyze)

## Source of truth

Agents read **minimal files per task.** Default order:

| Priority | Source | Purpose |
|:--------:|--------|---------|
| 1 | **Source code** under `Phathom/` | What shipped — behavior, schema, Swift paths |
| 2 | **`docs/decisions.md`** | Locked invariants and rationale |
| 3 | **Active hand-offs** (`docs/handoff/`): **`phase-3-rag-chat.md`**, **`ui-design-refresh.md`**, **`library-bulk-selection.md`** | Scoped specs / UX acceptance |
| 4 | **`README.md`** | Orientation for humans |

**Historical / completed phase specs:** `docs/archive/` — **opt-in only** (user asks, archaeology after code + decisions, or tracing superseded ideas). **Do not** use archive on cold start, for schema/pipeline/UI truth, or for RAG embedding decisions. If archive contradicts code or live docs → **ignore archive**.

**Conflict resolution:** **Code wins** over all prose. Among docs **`decisions.md` > hand-offs > README**. **Memory (agentmemory) never overrides decisions or code.**

## Context Entry Points (Read First)

To save tokens, **do not** scan the entire `/Phathom` directory. Use these specific paths:

- **Decisions / invariants:** `docs/decisions.md` — read indexed sections + matching rows before changing behavior shared across surfaces.
- **Active scope specs:** [`docs/handoff/phase-3-rag-chat.md`](docs/handoff/phase-3-rag-chat.md) (RAG Chat — roadmap), [`docs/handoff/ui-design-refresh.md`](docs/handoff/ui-design-refresh.md) (remaining UI polish), [`docs/handoff/library-bulk-selection.md`](docs/handoff/library-bulk-selection.md) (bulk select / undo — shipped).
- **Historical only:** [`docs/archive/`](docs/archive/) — see **Source of truth** section; not for implementation bootstrap.
- **Pipeline Logic:** `Phathom/Phathom/Services/BackgroundPipeline.swift` (background/foreground ingest + analyze).
- **LLM Bridge:** `Phathom/Phathom/Services/SharedLlamaInference.swift` (serialized GGUF session).
- **UI shell & navigation:** `Phathom/Phathom/Views/` — recall agentmemory **UI** topic first. Tab shell: `MainTabView` (Library | Chat placeholder | Add New); Settings via Library gear → `SettingsContent`. Primary surfaces: `LibraryTab` (`LibraryFilterBar`, **`LibrarySearchService`** filters incl. **`filterCategory`**) → `DetailView` (**`CategoryPicker`** sheets where relevant); capture in `AddNewTab`. Structural categories: **`PhathomCore.Category`**, **`LibraryCategoryFilterStorage`**, **`CategoryDisplayFormatter`**. UI binds SwiftData (`@Query` / `@Bindable`); never calls Llama directly—schedules work via `BackgroundPipeline` and `ProcessingRecovery`.
- **Roadmap Context:** **`docs/handoff/`** active files (**RAG Chat** + **UI design refresh**) — see bullets under **Active scope specs** above. Do **not** use **`docs/archive/`** for cold-start reads.

## Efficiency Rules (Token/Context Management)

1. **Implicit Knowledge:** Assume the `llama.cpp` C API is available via `import llama`. Do not ask to see the header files unless debugging a specific crash.
2. **Read code before docs:** Identify the smallest set of `.swift` files for the task, then dip into **`docs/decisions.md`** / hand-offs only where behavior isn’t obvious. **`docs/archive/`** only after code + decisions + active hand-offs fail—and **verify in code before acting**.
3. **Minimalist Reading:** Before modifying UI, only read the relevant `View` and its `Model`. Do not read the entire `App` struct.
4. **Session Awareness:** Always respect `SharedLlamaInference.withSession`. Never propose parallel LLM calls; they must be serialized to prevent memory corruption.
5. **Performance Fast-Path:** Be aware of `llama_memory_seq_cp` for KV cache reuse. One article prefill serves Summarize → Tags → Extracts. Maintain this optimization in any pipeline refactors.

## Getting Up to Speed (New Session)

- **Read README.md:** Read the root README.md file to understand the overall purpose of the app, its major capabilities, and high level structure.
- **Be Terse:** If the agent skill `caveman` is available, always use it unless/until the user disables it. If it is not, then always respond terse like _smart_ caveman: all technical substance stay, only fluff removed. Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for"). Technical terms exact. Code blocks unchanged. Errors quoted exact.

> [!EXAMPLE]
> Pattern: `[thing] [action] [reason]. [next step].`
> Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
> Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

- **Check Environment:** Verify `Phathom/vendor/llama/llama.xcframework` exists. If not, run `bash scripts/setup-llama-xcframework.sh`.
- **Build targets:** Use **iPhone 16 Pro or newer** simulator or device in Xcode. For routine CLI verification, run **`bash scripts/build-phathom.sh sim`** (first available simulator from Pro-first preference list in [`scripts/phathom-xcode-common.sh`](scripts/phathom-xcode-common.sh)); use **`bash scripts/build-phathom.sh device`** for generic `iphoneos`; reserve **`bash scripts/build-phathom.sh all`** for **xcframework refresh**, pre-release, or intentional device-signing checks. Project sets **`EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64`** so simulator builds match arm64-only `llama.xcframework` slices.
- **Simulator verify (token-efficient):** Follow **`### Verification ladder (token-efficient)`** below and the requestable Cursor rule **[`.cursor/rules/simulator-verify.mdc`](.cursor/rules/simulator-verify.mdc)** (`alwaysApply: false`). Tests: **`bash scripts/test-phathom.sh`** (`--grep`, `--test`, `--list`; skips `PhathomUITests`).
- **Verify GGUF Path:** The app uses security-scoped bookmarks. If testing in Simulator, remember it is **CPU-only**; don't optimize for GPU/ANE performance unless targeting a physical device.
- **Active Task:** Pipeline + on-device ingest shipped. Remaining roadmap: **RAG Chat** (`docs/handoff/phase-3-rag-chat.md`) and **ongoing UI polish** (`docs/handoff/ui-design-refresh.md`). Do **not** implement RAG or expand Chat tab unless explicitly directed.
- **Confirm With User:** Indicate understanding by saying "Read and ready" at the beginning of a new session.

### Verification ladder (token-efficient)

Goal: same confidence as a full raw `xcodebuild` dump, **minimal tokens** in agent context (see [`.cursor/rules/simulator-verify.mdc`](.cursor/rules/simulator-verify.mdc)).

1. **ReadLints** on touched Swift files (and **xcode-tools** issue list when Xcode is open).
2. **Compile on simulator:** **`bash scripts/build-phathom.sh sim`** or XcodeBuildMCP **`build_sim`** (prefer **incremental**, no **`clean`** unless DerivedData corruption).
3. **Warnings (hybrid):** Routine edits — Tier 1 is enough when clean. Also surface **warnings on touched `.swift`** (MCP / `rg '\\.swift:.*warning:'` on sim build **`fullLogPath`**; **cap ~40 lines** in chat) when **pre-merge** *or* the diff touches **`@MainActor`/strict concurrency**, **`BackgroundPipeline.swift`**, **`SharedLlamaInference.swift`**, or other inference/pipeline paths (Cursor rule expands).
4. **Tests:** Prefer **`bash scripts/test-phathom.sh --test`** / **`--grep`** for localized changes; run **full `test-phathom.sh`** once per logical feature / before merge. **Never paste** full build or test logs—**failure / warning snippets only** (≤40 lines default).
5. **Device / `all`:** **`bash scripts/build-phathom.sh device`** only for signing or device-specific code; **`all`** reserved for xcframework refresh / release-style verification—not after every edit.

**Copy-paste shortcuts**

- Small non-behavioral Swift fix — ReadLints → **`bash scripts/build-phathom.sh sim`** → on failure grep **`error:`** only (≤40 lines).
- Behavioral fix — above + **`bash scripts/test-phathom.sh --test <name>`** or **`--grep <pattern>`**.
- Pre-merge — sim build → Tier 2b warnings when policy says so → **`bash scripts/test-phathom.sh`**.

## Agent skills

### Issue tracker

Issues live in GitHub (`Danjohnsonnj/phathom`); use `gh` from this clone. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

Seven canonical labels: two category (`bug`, `enhancement`) + five state (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

Single-context; read `Phathom/` → `docs/decisions.md` → active hand-offs. See [`docs/agents/domain.md`](docs/agents/domain.md).

### Skills cheat sheet

When to slash vs ask; pipeline order. See [`docs/agents/skills-cheatsheet.md`](docs/agents/skills-cheatsheet.md).

## Agentmemory (long-term context)

Use the **agentmemory** MCP at session start and when saving durable insights. Memory is a **compressed index** (invariants, file map, recent decisions)—not a substitute for `docs/decisions.md` or source code.

Phathom-specific memories include **pipeline orchestration**, **llama.cpp backend** (xcframework supply chain, `LlamaCppRuntime` APIs, KV reuse), **UI shell**, **decisions gist**, **performance**, and **scope** — see the topic table below. For inference work, recall **both** pipeline and llama.cpp memories: pipeline = when/who schedules work; llama.cpp = how decode/sampling/KV behave.

### Agent obligations

1. **Session start:** Silently recall agentmemory for the task domain before broad file reads (e.g. pipeline, llama.cpp, decisions, performance, UI, **versioning**).
2. **Authority:** **Code** wins over all prose. **`docs/decisions.md`** wins over agentmemory **and** over hand-offs. Memory is a gist only—never overrides decisions or Swift sources. For cross-cutting behavior (inference lifecycle, schema, backup, archive), read the **full** `docs/decisions.md` when implementing or when edge cases matter—not only the index.
3. **Save after:** architectural decisions, perf root-causes/fixes, and non-obvious constraints the next session must not forget.
4. **Format saves as bullets**, not pasted doc paragraphs. Tag with concepts (`pipeline`, `KV-cache`, `decisions`, etc.).

### Topic memories (what to recall)

| Domain | Recall concepts | Code/doc anchors |
|--------|-----------------|------------------|
| Pipeline & inference | `pipeline`, `withSession`, `KV-cache` | `BackgroundPipeline.swift`, `SharedLlamaInference.swift`, `ModelManager.swift` |
| llama.cpp backend | `llama.cpp`, `xcframework`, `LlamaCppRuntime`, `Metal` | `Inference/LlamaCppRuntime.swift`, `vendor/llama/llama.xcframework`, upstream `~/Local Documents/repos/llama.cpp` |
| Decisions gist | `decisions`, `decisions.md`, `gist` | `docs/decisions.md` |
| Performance | `performance`, `thermal`, `PipelineMetrics` | README Llama perf section, pipeline metrics logs |
| Schema | `ContentItem`, **`Category`**, `processingStatus` | `Phathom/PhathomCore/Sources/PhathomCore/` (`Category.swift`, `ContentItem.swift`) |
| UI shell & pipeline bridge | `UI`, `LibraryTab`, `LibraryFilterBar`, `DetailView`, `CategoryPicker`, `navigation` | `Views/MainTabView.swift`, `Library/`, `Detail/`, `AddNew/`, `Settings/SettingsTab.swift`, `ProcessingRecovery.swift`, `Services/LibrarySearchService.swift` |
| UI design refresh | `tokens`, `AppPalette`, `IA`, `screens` | [`docs/handoff/ui-design-refresh.md`](docs/handoff/ui-design-refresh.md) — **`code` > decisions > brief** |
| Bulk library select | batch archive undo, notifications | [`docs/handoff/library-bulk-selection.md`](docs/handoff/library-bulk-selection.md), `MainTabView` |
| Archived docs (**opt‑in**) | `history`, Phase 1–2 snapshots | [`docs/archive/README.md`](docs/archive/README.md) — read **only** per **Source of truth** rules |
| Scope | `Phase-3`, `no-RAG`, `guardrails` | `docs/handoff/phase-3-rag-chat.md` |
| Dev bootstrap | `build`, `xcframework`, `test` | `scripts/build-phathom.sh`, [`scripts/test-phathom.sh`](scripts/test-phathom.sh), `scripts/phathom-xcode-common.sh`, [`scripts/phathom-tests-discover.py`](scripts/phathom-tests-discover.py), `AGENTS.md` |
| App versioning | `version`, `semver`, `MARKETING_VERSION`, `0.x.y` | `Phathom.xcodeproj/project.pbxproj`, `SettingsTab.swift`, `PhathomShare/Info.plist` |

### User phrase → agent action

| User says | Agent does |
|-----------|------------|
| "Recall agentmemory for …" | `memory_recall` / `memory_smart_search` on that domain |
| "Save to agentmemory …" | `memory_save` (right topic; short bullets) |
| "Update decisions memory" | Refresh decisions gist after `docs/decisions.md` changes |
| "What's in memory about X?" | Search and summarize hits |

### Session templates (user copy-paste)

**Cold start (implementation)**

> Resume Phathom. Recall pipeline, decisions, and performance memories. Task: [one sentence]. Read **Swift sources + `docs/decisions.md` first**; open hand-offs second; **`docs/archive/`** only if explicitly required.

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
- [ ] After landing plan-driven changes: **linter / IDE diagnostics** on touched files plus **incremental sim build**; add **warning grep on touched `.swift`** when **pre-merge** *or* the diff touches **`@MainActor`/concurrency**, **`BackgroundPipeline.swift`**, **`SharedLlamaInference.swift`**, or inference/pipeline paths — Swift 6 / default `MainActor` issues often appear as warnings only. See **`### Verification ladder (token-efficient)`** and [`.cursor/rules/simulator-verify.mdc`](.cursor/rules/simulator-verify.mdc).
