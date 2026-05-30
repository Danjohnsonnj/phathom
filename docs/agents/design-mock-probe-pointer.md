# Design mock probe — Phathom pointer

Global skill: [`design-mock-probe`](~/.cursor/skills/design-mock-probe/SKILL.md) (auto-invoked from natural phrases; pairs with `/grill-me` on lock passes).

| Key | Value |
|-----|--------|
| **mock_dir** | [`.design-mocks/`](../../.design-mocks/) — see [README](../../.design-mocks/README.md) |
| **handoff_doc** | [`docs/handoff/library-ui-evolution.md`](../handoff/library-ui-evolution.md) — §2.2 SwiftUI target · §2.3 inference · §3–§3.10 locked |
| **ship_target** | `Phathom/Phathom/Views/` (+ `AppPalette.swift`) |
| **discovery_gates** | **No Swift** during discovery unless explicitly green-lit; Chat RAG out of scope ([`phase-3-rag-chat.md`](../handoff/phase-3-rag-chat.md)) |

**Authority:** `Phathom/` code > [`docs/decisions.md`](../decisions.md) > hand-off > mocks.

**Agentmemory:** recall workflow via skill only; particulars stay in hand-off (see [`agentmemory.md`](agentmemory.md)).

**Discovery complete (May 2026):** 6 canonical mocks · [`ui-evolution-token-sheet.md`](../handoff/ui-evolution-token-sheet.md) · **Next:** [`ui-evolution-implementation-plan.md`](../handoff/ui-evolution-implementation-plan.md) (multi-phased; do not build from design hand-off directly).
