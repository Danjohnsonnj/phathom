# OKF-lite doc conventions

Navigation layer for Phathom docs — **behavior over conformance**. Partial migration is valid.

---

## Authority (highest wins)

1. **Swift source** (`Phathom/`)
2. [`docs/decisions.md`](../decisions.md)
3. Hand-off briefs ([`docs/handoff/`](../handoff/index.md))
4. Concept stubs ([`docs/concepts/`](../concepts/index.md))
5. **agentmemory** (gist only — never overrides above)

---

## Stub content rules

- **Frontmatter** (optional): `type`, `title`, `description`, `tags`, `anchor` (Swift path)
- **Body:** one-line `# Definition` + `# Links` section only
- **Never** paste decision rationale or agentmemory lessons into stubs
- **Pitfalls:** stay in agentmemory; stubs link `recall agentmemory tags …`

**Types:** `Glossary` · `Invariant` · `Handoff` · `DeliveryLog` · `AgentGuide`

**Migration trigger:** extract a term when it appears in **Active invariants index**, agents cold-read it often, or you edit that glossary row.

**Stop rule:** do not split remaining [`CONTEXT.md`](../../CONTEXT.md) rows until task UAT shows monolith read is costly.

**Permissive consumption:** missing concept file ≠ blocker.

---

## Product state

[`product-state.md`](product-state.md) is the canonical **what shipped now** summary. Agent-facing docs link here instead of re-stating roadmap status.

**On ship/defer:** update **`product-state.md` first**, then run staleness grep (below).

---

## Staleness fix tiers

| Tier | Where | Fix |
|------|-------|-----|
| **Banner/header** | Routing, status | Fix immediately (Phase 0+) |
| **Body gates** | Shipped specs | Superseded note or one-line status — no full rewrite |
| **Session logs** | Delivery docs | Keep history; fix top banner + locked tables only |
| **Archive** | `docs/archive/` | Do not rewrite bodies |

**Sweep command** (active docs; zero hits or explicit historical marker):

```bash
rg -i 'design probe next|Phases 0–2 done|frozen until Focus Phase A|read this file first when resuming|Chat tab remains a placeholder|ChatTab\.swift' \
  AGENTS.md README.md CONTEXT.md docs/agents/ docs/handoff/ \
  --glob '!docs/archive/**'
```

_Note:_ `ChatTab.swift` in implementation reference prose may remain if marked historical context.

---

## Ongoing hygiene

| Rule | Detail |
|------|--------|
| **Product state first** | Ship/defer/priority change → [`product-state.md`](product-state.md) before other agent docs |
| **Sweep on touch** | Editing agent-facing doc → run staleness grep; fix banners in same PR |
| **Archive shipped specs** | De-emphasize in [`handoff/index.md`](../handoff/index.md); move to archive only when cold-start confusion recurs twice |
| **Remove vs de-emphasize** | Remove duplicate routing; de-emphasize large historical specs; never delete decision rows or delivery session history |
| **Pitfalls** | agentmemory tags first; stub link second; [`product-state.md`](product-state.md) § Common agent pitfalls only if same mistake hits twice without memory |

A lightweight auto-attach rule ([`.cursor/rules/doc-hygiene.mdc`](../../.cursor/rules/doc-hygiene.mdc)) now surfaces the product-state-first + staleness-sweep reminder when editing agent-facing docs. Full playbook [`docs-hygiene.md`](docs-hygiene.md) remains **deferred** until Phase 0–1 UAT shows repeated stale routing.
