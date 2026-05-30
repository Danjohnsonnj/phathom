# Assessment: source-of-truth doc alignment (Phase 3)

_Date: 2026-05-30. Status: **complete — Outcome B**._

## Executive summary

Phathom already had a coherent doc hierarchy: **code → `docs/decisions.md` → active hand-offs → README**, with archive opt-in. **`docs/agents/domain.md`** wires mpocock skills to that chain.

**Outcome B applied (2026-05-30):** thin **`CONTEXT.md`** glossary added; **`library-bulk-selection.md`** moved to **`docs/archive/`**; read order and links updated in **`AGENTS.md`**, **`domain.md`**, **`decisions.md`**. **`decisions.md`** remains canonical for rationale.

---

## Current inventory

| Asset | Lines / size | Role today |
|-------|----------------|------------|
| `Phathom/` Swift | — | Behavior wins |
| `docs/decisions.md` | ~85 lines, ~40 rows | Append-only decision log + **Active invariants index** (de facto glossary seed) |
| `docs/handoff/` | 1 active file | Scoped spec: RAG Chat roadmap |
| `docs/archive/` | 5 files + README | Historical; drift table in `archive/README.md` |
| `docs/agents/domain.md` | ~50 lines | Skill consumer rules (Phathom-tailored) |
| `AGENTS.md` | ~183 lines | Agent cold-start + source-of-truth order |
| `README.md` | ~109 lines | Human orientation |

**Missing:** `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/adr/`.

---

## Question 1 — Add `CONTEXT.md` glossary?

### Assessment

**Duplication risk: medium.** The **Active invariants index** in `decisions.md` already lists domain anchors (`ContentItem`, `withSession`, `processingStatus`, `Category`, backup v3, etc.). Hand-offs add feature-scoped vocabulary (RAG, UI tokens). A separate glossary would repeat many terms unless scoped narrowly.

**Benefit for skills: medium-high.**

- **`to-issues`** — issue titles/bodies should use canonical terms; a one-page glossary reduces synonym drift without reading full decision rows.
- **`improve-codebase-architecture`** — skill description still says `CONTEXT.md` + `docs/adr/`; Phathom's `domain.md` redirects, but a real `CONTEXT.md` would match stock skill expectations with zero skill edits.

**Token cost:** Small if glossary-only (~30–60 terms, no rationale). Large if it becomes a second decisions doc.

### Options

| Choice | Effort | Risk |
|--------|--------|------|
| No `CONTEXT.md` | None | Agents grep decisions index + code; mpocock skills need `domain.md` pointer |
| Thin `CONTEXT.md` (terms + one-line defs, links to decisions rows) | Low (~1 session) | Must discipline: glossary never overrides decisions |
| Full domain wiki in `CONTEXT.md` | High | Duplicates decisions + hand-offs; maintenance burden |

---

## Question 2 — `docs/adr/` vs keep `docs/decisions.md`?

### Assessment

**`decisions.md` already functions as ADR log:** dated table, rationale column, phase tags, superseded appendix. Format differs from numbered files (`0001-foo.md`) but authority and append-only discipline match ADR intent.

**Migration cost: high, value low.**

- ~40 rows would need splitting or symlink/index maintenance
- Link rot in `AGENTS.md`, hand-offs, agentmemory, archive cross-refs
- Agents already trained on "read decisions.md index + matching rows"

**When numbered ADRs help:** human browsing, per-decision PR discussion links, very large decision corpora. Phathom at ~85 lines is not there yet.

### Options

| Choice | Effort | Risk |
|--------|--------|------|
| Keep `decisions.md` only (**recommended**) | None | None |
| Dual track: new decisions as `docs/adr/NNNN-*.md`, index in decisions.md | Medium ongoing | Two formats until backlog migrated |
| Full migration to `docs/adr/` | High one-time | Link rot; archive confusion |

---

## Question 3 — Hand-offs vs decisions boundaries?

### Assessment

**Boundary is already documented** in `AGENTS.md`, `decisions.md` header, and `docs/agents/domain.md`:

| Layer | Holds | Examples |
|-------|--------|----------|
| **Decisions** | Locked invariants, schema, pipeline rules | `withSession`, archive 48h, no CloudKit, KV reuse |
| **Hand-offs** | Scoped delivery specs + acceptance | `phase-3-rag-chat.md` |
| **Shipped hand-offs** | Kept as spec/UX reference | `library-bulk-selection.md`, `ui-design-refresh.md`, `media-vision-v1-qa.md` |

**Gray areas:**

- `media-vision-v1-qa.md` — **archived** (shipped); device QA matrix historical; automated coverage in PhathomTests.
- `ui-design-refresh.md` (42k) — **archived** (shipped on `main`); agents cold-start from Views + `AppPalette`, not this file.
- Shipped specs in `handoff/` vs moving to `archive/` — product choice, not structural bug.

**Recommendation:** Shipped specs live in `docs/archive/`; `docs/handoff/` holds active roadmap only (`phase-3-rag-chat.md`).

---

## Question 4 — Archive policy unchanged?

### Assessment

**Policy is strong:** `docs/archive/README.md` drift table + AGENTS opt-in. Agents should not bootstrap from archive.

**Optional enhancement (low value):** Link archive README from `domain.md` "when to opt in" — already covered by "only when user directs."

**Recommendation:** Leave archive policy unchanged (Outcome A/B compatible).

---

## Skill compatibility matrix

| Skill | Expects | Phathom today | Gap if status quo |
|-------|---------|---------------|-------------------|
| `to-issues` | Domain glossary vocabulary | `decisions.md` index + `domain.md` | Minor — works via domain.md |
| `to-prd` | Same | Same | None |
| `triage` | Domain + `.out-of-scope/` | Configured | None |
| `improve-codebase-architecture` | `CONTEXT.md`, `docs/adr/` | Redirect in `domain.md` | Skill description mismatch; optional CONTEXT fixes |
| `grill-with-docs` (not symlinked) | Updates CONTEXT + ADRs inline | N/A | Not installed |

---

## Outcome options (pick one)

| ID | Name | What changes |
|----|------|--------------|
| **A** | **Status quo** | Only `docs/agents/domain.md`; no new root files |
| **B** | **Glossary add** | Add thin `CONTEXT.md` (terms only); `decisions.md` stays canonical; update `domain.md` + AGENTS one-liner |
| **C** | **Dual track** | New decisions → `docs/adr/NNNN-*.md`; `decisions.md` becomes index (or new rows append to both) |
| **D** | **Full alignment** | `CONTEXT.md` + migrate/create `docs/adr/` + migration plan |

---

## Agent recommendation

**Prefer B if you want one small improvement; else A.**

- **A** — zero maintenance; current setup passed Phase 2 smoke; `domain.md` is enough for triage workflow.
- **B** — ~30–60 min: extract glossary from decisions index + `PhathomCore` public types; link each term to decisions row or Swift file; satisfies stock mpocock skills without splitting ADRs.
- **C/D** — defer until decision log exceeds ~150 rows={or you need per-decision GitHub permalinks for humans.

---

## Interview record

_Fill after user responds._

| Field | Value |
|-------|-------|
| Chosen outcome | **B** — thin `CONTEXT.md` + archive shipped hand-offs (2026-05-30) |
| Hand-off moves | `library-bulk-selection.md` → `docs/archive/` |
| CONTEXT.md scope | Glossary only (~40 terms); links to decisions rows + Swift anchors |
| ADR policy | Deferred — keep `docs/decisions.md` only |
| Archive policy | Unchanged opt-in; `archive/README.md` updated |

---

## Comparative analysis (decision aid)

Criteria: **productivity** (human + agent maintenance), **progressive agent context** (token-efficient cold start, read order), **useful history** (audit trail, no link rot).

### Outcome A — Status quo

| Criterion | Assessment |
|-----------|------------|
| Productivity | **Best short-term** — zero migration; `domain.md` already wired. Ongoing cost: agents may open full `decisions.md` or long hand-offs when a term is unclear. |
| Progressive context | **Good** if agents obey AGENTS minimal-read rules. **Weak** for mpocock skills that grep for `CONTEXT.md` — rely on `domain.md` redirect. |
| History | **Strong** — single append-only `decisions.md`; archive already isolated. |
| Risk | Synonym drift in GitHub issue titles; `improve-codebase-architecture` skill description mismatch. |

### Outcome B — Thin `CONTEXT.md` glossary

| Criterion | Assessment |
|-----------|------------|
| Productivity | **Low one-time cost** (~30–60 min extract from decisions index + `PhathomCore`). **Small ongoing**: add term to CONTEXT when a decision introduces new vocabulary (link to decisions row). |
| Progressive context | **Best cold-start for issue/planning skills** — ~1–2 page glossary before 85-line decision table or 42k UI hand-off. Agents get names first, rationale on demand. |
| History | **Strong** — CONTEXT holds *names* only; `decisions.md` keeps *why*; no split audit trail. |
| Risk | Duplication if glossary copies rationale paragraphs — mitigate with one-line defs + links only. |

### Outcome C — Dual track ADRs (new only)

| Criterion | Assessment |
|-----------|------------|
| Productivity | **Medium ongoing** — every new decision: file + index row (or cross-link). Two formats coexist indefinitely unless backlog migrated. |
| Progressive context | **Improves at scale** — read `docs/adr/2026-05-27-pipeline-pause.md` instead of scanning table. **Neutral today** at ~40 rows. |
| History | **Excellent for new work** — per-decision files, PR-friendly. **Split brain** until old rows migrated or permanently indexed-only in table. |
| Risk | Agents read wrong format; link rot between table and files. |

### Outcome D — Full alignment

| Criterion | Assessment |
|-----------|------------|
| Productivity | **Worst short-term** — migration project + CONTEXT + ADR index maintenance. |
| Progressive context | **Best at maturity** — standard mpocock layout. Overkill until decision count or team size grows. |
| History | **Best archival** if migration done carefully with redirects in `decisions.md` index. |
| Risk | Highest link rot; highest agent confusion during transition. |

### Hand-off: archive shipped specs (user preference)

| Action | Rationale |
|--------|-----------|
| Move **`library-bulk-selection.md`** → `docs/archive/` | Shipped; acceptance criteria live in code + decisions row (2026-05-12). Reduces `handoff/` to active work only. |
| **Keep** `phase-3-rag-chat.md` | Active roadmap — not shipped. |
| **Move** `ui-design-refresh.md` → `docs/archive/` | Shipped on `main`; §12 design-system gate incomplete — code + `AppPalette` authoritative. |
| **Move** `media-vision-v1-qa.md` → `docs/archive/` | Shipped; device QA matrix historical; PhathomTests cover automated sign-off. |
| Update `archive/README.md`, `AGENTS.md`, `domain.md` | Point agents at new paths; mark bulk-select as archived spec. |

**Progressive context win:** `docs/handoff/` holds one active file (`phase-3-rag-chat.md`) — agents less likely to cold-read shipped specs.

### Recommendation matrix

| If your priority is… | Lean toward |
|------------------------|-------------|
| Zero work now | **A** + archive shipped hand-off only |
| Better issue/triage/planning vocabulary | **B** + archive shipped hand-off |
| Human-readable decision permalinks for *new* decisions | **C** (not D) |
| Large team / 100+ decisions someday | Plan **C** now, **D** never unless forced |

**Suggested combo:** **B + archive shipped hand-offs** — best productivity/context tradeoff without ADR migration tax.

