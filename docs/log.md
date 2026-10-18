# Docs chronology

## 2026-10-18 — llama.cpp b11719 Metal 4 refresh

Rebuilt the vendored `llama.xcframework` from llama.cpp b11719 with embedded Metal tensor kernels and the current `libmtmd` hash dependency. Updated the inference bridge for the new bitmap-init API. Simulator build succeeded; physical iPhone 18 Pro verification confirmed f16/bfloat tensor probes, embedded Metal library use, and working inference. Performance improvement was not claimed because the user observed no major difference and the sample was too small.

Post-build refresh: okf-alignment tech brief architecture sections updated to match shipped tree.

## 2026-10-17 — OKF alignment complete (Phases 4–5)

Touch-later manifest appended to okf-alignment tech brief; summary-progress HANDOFF linked to product-state **Analysis progress**; okf-alignment HANDOFF marked done.

## 2026-10-17 — Glossary split (Phase 3)

Split `CONTEXT.md` tables into `docs/concepts/` stubs with OKF v0.2 frontmatter; rebuilt concepts indexes; added frontmatter to `decisions.md`, `design-tokens.md`, `product-state.md`, `onboarding.md`, `domain.md`. `CONTEXT.md` is now a pointer.

## 2026-10-17 — OKF hub (Phase 2)

Created `docs/index.md` (Settled | In progress), `docs/log.md`, `docs/agents/index.md`, and `.cursor/skills/docs-maintenance/SKILL.md`. Trimmed `AGENTS.md` to point at the hub; extended doc-hygiene for `docs/**/*.md`.
