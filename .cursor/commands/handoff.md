---
name: handoff-chat
description: Compress the current chat history into a dense, machine-readable handoff packet for the next LLM session. Use when the user says "handoff", "handoff chat", "compress chat", "pack context", "summarize for next session", or asks to transfer conversation state, decisions, and pending tasks to a new session with minimal tokens.
---

# Conversation Handoff & Token Compression

Compress the current chat history into a dense handoff packet the next LLM session can resume from.

## Goals

- Minimize output tokens using technical shorthand.
- Retain all state, logic decisions, and pending tasks.
- Format for machine readability by the next LLM session.

## Process

Run these steps before emitting the packet:

1. Scan the user's most recent goal and any pinned context (`CLAUDE.md`, `AGENTS.md`, `README.md`) for the project objective.
2. Walk recent tool calls, file edits, and errors in reverse chronological order; capture decisions and *why*, not just *what*.
3. Capture environment anchors if available: `git status`, current branch, cwd, last commit hash. If unavailable, mark `ENV` partial rather than guessing.
4. Classify every captured fact into exactly one schema field below. If a fact does not fit, drop it.
5. Apply Compression Rules, then run the Self-check before emitting.

## Output Format

Emit exactly one `<handoff>` block **wrapped in a triple-backtick code fence**, no surrounding prose, no preamble, no closing remarks. The fence guarantees newlines survive rendering and makes the packet copy-paste-scannable. The fenced output must match the layout below byte-for-byte (one field per line, bullets indented exactly two spaces):

```
<handoff v="1">
GOAL: <one-line objective>
ENV: <stack | repo | branch:cwd>
STATE: <touched files | configs | env-var names — values redacted>
DECISIONS:
  - <decision> -> <reason>
DONE:
  - <completed step>
AVOID:
  - <failed approach> -> <why>
TODO:
  - <pending task in priority order>
NEXT: <single concrete first action>
BLOCKED: <unresolved error | missing info | none>
</handoff>
```

`GOAL` and `NEXT` are required. Drop any other field entirely if empty rather than emitting a placeholder.

## Compression Rules

- Use fragments, not sentences.
- Use `->` for workflows and cause/effect.
- Omit conversational filler ("The user asked for...").
- Reference code blocks by file path + line range only (e.g., `src/auth/jwt.ts:42-128`). Never use `...` ellipses inside paths; use the full path or omit the reference.
- Hard cap: ≤ 50 lines, ≤ ~1500 tokens.
- Never emit secret values. Emit env-var names, file paths, or key IDs only.
- Prefer priority order over completeness; truncate the tail of `TODO`/`DONE` if needed to stay under the cap.
- Literal line layout (non-negotiable, even under token pressure): each field label starts at column 0 of its own line; each bullet under `DECISIONS`/`DONE`/`AVOID`/`TODO` is on its own line, indented exactly two spaces. Never run two fields together on one line, never inline bullets after a label.

## Example

This block is **normative** — match its layout (line breaks, indentation, fence) byte-for-byte. The example is not decorative.

```
<handoff v="1">
GOAL: migrate /api/v1/auth from HS256 JWT to RS256 with rotatable keys
ENV: node 22.11 | pnpm 10.33 | repo:acme-api | branch:auth/rs256-rotate | cwd:packages/api
STATE: src/auth/jwt.ts:42-128 | src/auth/keys.ts (new) | env names: AUTH_PRIV_KEY_PEM, AUTH_PUB_KEY_PEM, AUTH_KID
DECISIONS:
  - RS256 over ES256 -> existing CDN supports RSA verify only
  - kid header required -> rotation w/o downtime
  - keys via env, not KMS -> KMS adapter deferred to phase 2
DONE:
  - signer + verifier in src/auth/jwt.ts:42-128
  - kid plumbed through middleware src/middleware/auth.ts:18
  - unit tests src/auth/__tests__/jwt.test.ts (12 cases green)
AVOID:
  - jose v5 default import -> ESM/CJS interop breaks build; use named imports
  - generating keys at boot -> non-deterministic across pods
TODO:
  - integration test: rotate kid mid-request, verify both keys accepted
  - update OpenAPI spec packages/api/openapi.yaml (security schemes)
  - rollout doc docs/runbooks/auth-rs256-rotation.md
NEXT: write rotation integration test in src/auth/__tests__/rotation.test.ts using two seeded kids
BLOCKED: none
</handoff>
```

## Self-check

Before emitting, verify:

- Output is wrapped in a triple-backtick code fence and every field/bullet starts on its own line (column 0 for fields, column 2 for bullets); no two fields share a line.
- `GOAL` and `NEXT` are non-empty and `NEXT` is a single concrete action.
- No field contains a secret value (token, password, API key, PEM body) — names and locations only.
- Every `TODO` item is traceable to the `GOAL`, a `DECISION`, an `AVOID`, or `BLOCKED`; if not, the missing rationale belongs in `DECISIONS`.
- Total lines ≤ 50; if over, compress `DONE` and `TODO` tails first, never `DECISIONS` or `AVOID`.
