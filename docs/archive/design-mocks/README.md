# Design mocks (HTML/CSS) — archived

**Visual reference only** — not shipped UI. Locked §3 choices: [`library-ui-evolution.md`](../library-ui-evolution.md).

**Location:** Moved from repo-root `.design-mocks/` (May 2026 post-rollout). Kept for Safari parity review; safe to prune later — **`Phathom/`** + [`decisions.md`](../decisions.md) remain authoritative.

## Purpose

Static Safari mocks probed layout, spacing, and material language before SwiftUI shipped (Phases 0–4b).

**Workflow (historical):** Global skill **`design-mock-probe`** ([`design-mock-probe-pointer.md`](../../agents/design-mock-probe-pointer.md)) — grill-me → lock hand-off → subagent HTML → Safari review → delete forks.

**Ship target:** SwiftUI in `Phathom/`. Translate tokens, rhythm, and hierarchy — do not port HTML structure, Geist, or review chrome. Token/button reference: [`design-tokens.md`](../design-tokens.md).

## Canonical files

| File | Surface |
|------|---------|
| `library-ad-search-b-toolbar.html` | Library — at rest + Search active; pipeline in actions row |
| `detail-ad-full-hairline-a.html` | Detail — full hairline A |
| `add-new-ad-filled-card-a.html` | Add New — Web · Note · Photo × Starting + Filled |
| `notebook-ad-hairline-feed-a.html` | Notebook — Empty + Populated hairline feed |
| `chat-ad-placeholder-a.html` | Chat placeholder — coming-soon shell |
| `settings-ad-grouped-a.html` | Settings — Configured · Primary unset · Missing file |

Discovery HTML **complete** — [rollout complete](../ui-evolution-implementation-plan.md#15-cold-start--rollout-complete).

Open locally in Safari (`open docs/archive/design-mocks/<file>.html` from repo root).

## Rules

- **Reference mode** — new UI work: **`Phathom/`** + [`decisions.md`](../decisions.md) UI rows; mocks for look-and-feel parity only.
- Rejected explorations were **deleted** after lock — do not resurrect without a new fork.
- On conflict: **`Phathom/` code** > `docs/decisions.md` > archive hand-off > mocks.
- Mocks are **not exhaustive** — see archive [§2.3](../library-ui-evolution.md#23-agent-inference-mocks-are-not-exhaustive).
- **Links:** always `a { text-decoration: none; color: inherit; }` in mock CSS (matches SwiftUI — no underlines).
- **Push nav (`.detail-nav`):** **22px** horizontal padding — Swift: **`DetailPushNavBar`** + `.safeAreaInset(edge: .top)`.
- **Push back (`.detail-nav-back`):** flat accent chevron only (`background: none`, no border/shadow/glass).
- **Detail share (`.detail-nav-share`):** flat **secondary** icon only — **8px** pad on icon.
- **Sheet toolbar (Close / Cancel / Done):** flat accent or destructive text — **no** liquid-glass capsule; labels **never truncate** (Swift: **`FlatToolbarTextItem`** + **`sharedBackgroundVisibility(.hidden)`** + **`phathomToolbarTextLabel`**). See [`design-tokens.md`](../design-tokens.md) §5.1 / §6.
