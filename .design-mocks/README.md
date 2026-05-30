# Design mocks (HTML/CSS)

**Discovery only** — not shipped UI. Authoritative choices: [`docs/handoff/library-ui-evolution.md`](../docs/handoff/library-ui-evolution.md).

## Purpose

Static Safari mocks probe layout, spacing, and material language before SwiftUI work.

**Workflow:** Build or update mock HTML in a **subagent** (parallel subagents OK for exploration). **Main session** runs grill-me, locks decisions in [`library-ui-evolution.md`](../docs/handoff/library-ui-evolution.md), then delegates mock implementation. They are **visual and behavioral guidance**, not a literal implementation spec.

**Ship target:** SwiftUI in `Phathom/`. Translate tokens, rhythm, and hierarchy — do not port HTML structure, Geist, or review chrome (device frame, status bar).

## Canonical files

| File | Surface |
|------|---------|
| `library-ad-search-b-toolbar.html` | Library — at rest + Search active |
| `detail-ad-full-hairline-a.html` | Detail — full hairline A |
| `add-new-ad-filled-card-a.html` | Add New — Web · Note · Photo × Starting + Filled |
| `notebook-ad-hairline-feed-a.html` | Notebook — Empty + Populated hairline feed |

**Next mock (not started):** `chat-ad-placeholder-*.html` — see hand-off §3.9.

Open locally in Safari. Files may be gitignored; keep in repo workspace for review.

## Rules

- **No Swift** during discovery unless explicitly green-lit.
- Rejected explorations are **deleted** after lock — do not resurrect without a new fork.
- On conflict: **`Phathom/` code** > `docs/decisions.md` > hand-off > mocks.
- Mocks are **not exhaustive** — interactions omitted from HTML (tag edit, sheets, navigation) stay governed by shipped Swift + hand-off [§2.3](../docs/handoff/library-ui-evolution.md#23-agent-inference-mocks-are-not-exhaustive).
