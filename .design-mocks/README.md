# Design mocks (HTML/CSS)

**Discovery only** — not shipped UI. Authoritative choices: [`docs/handoff/library-ui-evolution.md`](../docs/handoff/library-ui-evolution.md).

## Purpose

Static Safari mocks probe layout, spacing, and material language before SwiftUI work.

**Workflow:** Global skill **`design-mock-probe`** ([`docs/agents/design-mock-probe-pointer.md`](../docs/agents/design-mock-probe-pointer.md)) — grill-me in main session → lock hand-off → subagent HTML → Safari review → delete forks. Mocks are **visual reference** with the hand-off, **not** implementation specs (see hand-off §2.2–§2.3).

**Ship target:** SwiftUI in `Phathom/`. Translate tokens, rhythm, and hierarchy — do not port HTML structure, Geist, or review chrome (device frame, status bar).

## Canonical files

| File | Surface |
|------|---------|
| `library-ad-search-b-toolbar.html` | Library — at rest + Search active; pipeline in actions row |
| `detail-ad-full-hairline-a.html` | Detail — full hairline A |
| `add-new-ad-filled-card-a.html` | Add New — Web · Note · Photo × Starting + Filled |
| `notebook-ad-hairline-feed-a.html` | Notebook — Empty + Populated hairline feed |
| `chat-ad-placeholder-a.html` | Chat placeholder — coming-soon shell |
| `settings-ad-grouped-a.html` | Settings — Configured · Primary unset · Missing file |

Discovery HTML **complete** — Swift Phases **0–4b shipped**; [implementation plan §15 rollout complete](../docs/handoff/ui-evolution-implementation-plan.md#15-cold-start--rollout-complete).

Open locally in Safari. Files may be gitignored; keep in repo workspace for review.

## Rules

- **No Swift** during discovery unless explicitly green-lit.
- Rejected explorations are **deleted** after lock — do not resurrect without a new fork.
- On conflict: **`Phathom/` code** > `docs/decisions.md` > hand-off > mocks.
- Mocks are **not exhaustive** — interactions omitted from HTML (tag edit, sheets, navigation) stay governed by shipped Swift + hand-off [§2.3](../docs/handoff/library-ui-evolution.md#23-agent-inference-mocks-are-not-exhaustive).
- **Links:** always `a { text-decoration: none; color: inherit; }` in mock CSS (matches SwiftUI — no underlines).
- **Push nav (`.detail-nav`):** **22px** horizontal padding — back chevron leading edge aligns with scroll content (`--rhythm`). Swift: **`DetailPushNavBar`** + `.safeAreaInset(edge: .top)` (not system toolbar).
- **Push back (`.detail-nav-back`):** flat accent chevron only (`background: none`, no border/shadow/glass).
- **Detail share (`.detail-nav-share`):** flat **secondary** icon only — **8px** pad on icon.
