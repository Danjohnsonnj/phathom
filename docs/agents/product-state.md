# Product state (agent snapshot)

**Canonical what-shipped-now summary.** Ground in **code + [`decisions.md`](../decisions.md) active index** — not delivery session logs. Update this file first when shipping or deferring features (append date + one line).

**Last updated:** 2026-06-20 (OKF-lite Phase 0 baseline)

---

## Shipped

| Area | State |
|------|-------|
| **Tab bar** | **Library · Notebook · Focus · Add New** — no Chat tab (`FocusTab` replaced deleted Chat placeholder). Verify: [`MainTabView.swift`](../../Phathom/Phathom/Views/MainTabView.swift) |
| **Pipeline / ingest** | Scrape → embed → analyze; serialized **`withSession`** |
| **Focus Stack v1** | Phases **A + B + A+** (Library long-press add/remove) |
| **macOS v1** | Native Apple Silicon target shipped per **2026-06-13** decision — opt-in hand-offs: [`macos-v1-delivery.md`](../handoff/macos-v1-delivery.md) |

## Not started / deferred

| Area | State |
|------|-------|
| **Focus Phase C** | Connect / Thread — **not started**; opt-in [`focus-stack-delivery.md`](../handoff/focus-stack-delivery.md) |
| **RAG / Chat** | **Deferred** — no standalone Chat tab; schema retains `ChatThread` / `ChatMessage` for possible thread-scoped assist |

## Default agent cold-start

[`AGENTS.md`](../../AGENTS.md) → **this file** → task index ([`concepts/`](../concepts/index.md), [`handoff/`](../handoff/index.md), or [`decisions.md`](../decisions.md) active index) → at most **one** scoped hand-off when the task requires it.

**Do not** default-read [`focus-stack-delivery.md`](../handoff/focus-stack-delivery.md) unless resuming Focus follow-ups (Phase C) or explicit delivery wrap-up.

---

## Common agent pitfalls

_(Max ~10 bullets; prune stale. Encode repeat mistakes here only after agentmemory tag recall failed twice.)_

- **Parallel Llama calls** — forbidden; use **`withSession`** only.
- **Default cold-start via delivery logs** — use this file + indexes instead.
- **Implementing Chat/RAG tab** — deferred unless explicitly directed.
