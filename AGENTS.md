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
- **Pipeline Logic:** `Phathom/Pipeline/` (Coordinates background/foreground ingestion).
- **LLM Bridge:** `Phathom/Inference/SharedLlamaInference.swift` (Singleton managing the GGUF session).
- **Roadmap Context:** `docs/handoff/` (Current focus: Phase 2 Pipeline).

## Efficiency Rules (Token/Context Management)

1. **Implicit Knowledge:** Assume the `llama.cpp` C API is available via `import llama`. Do not ask to see the header files unless debugging a specific crash.
2. **Minimalist Reading:** Before modifying UI, only read the relevant `View` and its `Model`. Do not read the entire `App` struct.
3. **Session Awareness:** Always respect `SharedLlamaInference.withSession`. Never propose parallel LLM calls; they must be serialized to prevent memory corruption.
4. **Performance Fast-Path:** Be aware of `llama_memory_seq_cp` for KV cache reuse. One article prefill serves Summarize → Tags → Extracts. Maintain this optimization in any pipeline refactors.

## Getting Up to Speed (New Session)

- **Check Environment:** Verify `Phathom/vendor/llama/llama.xcframework` exists. If not, run `bash scripts/setup-llama-xcframework.sh`.
- **Verify GGUF Path:** The app uses security-scoped bookmarks. If testing in Simulator, remember it is **CPU-only**; don't optimize for GPU/ANE performance unless targeting a physical device.
- **Active Task:** We are currently in **Phase 2 (Pipeline Refinement)**. Phase 3 (RAG/Chat) is a placeholder—do not implement RAG logic unless explicitly directed.

## PR & Development Checklist

- [ ] Ensure all SwiftData changes include a migration plan or a "Clear Library" debug option.
- [ ] Update `docs/decisions.md` if changing the inference lifecycle.
- [ ] Verify that new ingest paths support `sourceMarkdown` fallback.
