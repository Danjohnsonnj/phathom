# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these (in order)

1. **Swift source under [`Phathom/`](../../Phathom/)** — behavior wins over prose.
2. **[`docs/agents/product-state.md`](product-state.md)** — what shipped / deferred now.
3. **[`CONTEXT.md`](../../CONTEXT.md)** — domain glossary (canonical term names; one-line defs; links to decisions).
4. **[`docs/concepts/index.md`](../concepts/index.md)** — term lookup stubs (**links only**; missing file → CONTEXT row).
5. **[`docs/decisions.md`](../decisions.md)** — locked invariants and decision log (ADR-equivalent; append-only). **Wins over CONTEXT on conflict.**
6. **Hand-offs (opt-in)** — [`docs/handoff/index.md`](../handoff/index.md); read one scoped file when the task requires depth.
7. **[`README.md`](../../README.md)** — human orientation only.

**Explicit opt-out:** [`docs/archive/`](../archive/) — do **not** bootstrap from archive. Shipped specs (e.g. [`library-bulk-selection.md`](../archive/library-bulk-selection.md), [`ui-design-refresh.md`](../archive/ui-design-refresh.md), [`library-ui-evolution.md`](../archive/library-ui-evolution.md), [`media-vision-v1-qa.md`](../archive/media-vision-v1-qa.md)) live here for archaeology only.

**Layout:** single-context (no `CONTEXT-MAP.md`). No `docs/adr/` — use **`docs/decisions.md`** for rationale.

If any optional file is missing, proceed silently — don't suggest creating it upfront.

**Permissive consumption:** missing concept stub or hand-off file is not a blocker — fall back to [`CONTEXT.md`](../../CONTEXT.md) or [`product-state.md`](product-state.md).

## File structure

```
/
├── CONTEXT.md                  ← domain glossary (names)
├── Phathom/                    ← source of truth for behavior
├── docs/
│   ├── decisions.md            ← invariants and decision log
│   ├── handoff/                ← active scoped specs (see index.md)
│   ├── concepts/               ← term lookup stubs (links only)
│   ├── archive/                ← shipped / historical specs
│   └── agents/                 ← issue tracker + triage + domain + onboarding + agentmemory (this folder)
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
