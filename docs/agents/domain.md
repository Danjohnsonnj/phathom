# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these (in order)

1. **Swift source under [`Phathom/`](../../Phathom/)** — behavior wins over prose.
2. **[`CONTEXT.md`](../../CONTEXT.md)** — domain glossary (canonical term names; one-line defs; links to decisions).
3. **[`docs/decisions.md`](../decisions.md)** — locked invariants and decision log (ADR-equivalent; append-only). **Wins over CONTEXT on conflict.**
4. **Active hand-offs** — read only when the task touches that scope:
   - [`docs/handoff/phase-3-rag-chat.md`](../handoff/phase-3-rag-chat.md) (RAG Chat roadmap)
   - [`docs/handoff/ui-design-refresh.md`](../handoff/ui-design-refresh.md) (remaining UI polish)
   - Other files under `docs/handoff/` only when the user directs.
5. **[`README.md`](../../README.md)** — human orientation only.

**Explicit opt-out:** [`docs/archive/`](../archive/) — do **not** bootstrap from archive. Shipped specs (e.g. [`library-bulk-selection.md`](../archive/library-bulk-selection.md)) live here for archaeology only.

**Layout:** single-context (no `CONTEXT-MAP.md`). No `docs/adr/` — use **`docs/decisions.md`** for rationale.

If any optional file is missing, proceed silently — don't suggest creating it upfront.

## File structure

```
/
├── CONTEXT.md                  ← domain glossary (names)
├── Phathom/                    ← source of truth for behavior
├── docs/
│   ├── decisions.md            ← invariants and decision log
│   ├── handoff/                ← active scoped specs
│   ├── archive/                ← shipped / historical specs
│   └── agents/                 ← issue tracker + triage + domain (this folder)
└── README.md
```

## Use the project's vocabulary

When your output names a domain concept (issue title, refactor proposal, test name), use terms from **`CONTEXT.md`** and **`docs/decisions.md`** — e.g. `ContentItem`, `processingStatus`, `withSession`, `Category`, `BackgroundPipeline`.

Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, note the gap rather than inventing language.

## Flag decision conflicts

If your output contradicts a row in **`docs/decisions.md`**, surface it explicitly rather than silently overriding:

> _Contradicts decisions.md (inference lifecycle) — but worth reopening because…_

**Conflict resolution:** Code wins over all prose. Among docs, `decisions.md` > hand-offs > README. Agentmemory never overrides decisions or code.
