# Library bulk selection & batch archive (**shipped**)

**Status:** Implemented. **Authority:** [`docs/decisions.md`](../decisions.md) row **2026-05-12** (Bulk Library triage + batch archive undo).

Agents: behavior lives in **`MainTabView`**, **`LibraryTab`**, and notification payloads — read code for edge cases.

## Behavior

- **Select mode:** multi-select rows in **`List`** applies **`ReadStatus`** or **archive** to many items in **one save** (and **`LibraryContentChangeNotifier`** fires once per bulk action where specified).
- **`phathomDidArchiveItem` notification:** Primary payload **`itemIDs`** — `[String]` UUID strings (plist-safe). **`MainTabView`** parses **`itemIDs`** first; else falls back to legacy **`itemID`** (`UUID`). Single-item notifications may mirror **`itemID`** for compatibility.
- **Undo snackbar (~3 s):** Restores **entire last archived batch**. Consecutive archives replace the batch (same semantics as single archive, scaled up).

## Out of scope

This doc restates decisions only; UI layout and Accessibility details belong in **code** + [`ui-design-refresh.md`](ui-design-refresh.md) where cited.
