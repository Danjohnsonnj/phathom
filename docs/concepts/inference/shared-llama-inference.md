---
type: Glossary
title: SharedLlamaInference
description: Single shared Llama session; primary vs optional tagging GGUF bookmarks.
tags: [inference, pipeline]
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:20:00Z" }
resource: Phathom/Phathom/Services/SharedLlamaInference.swift
sources:
  - id: decision-2026-05-15
    resource: docs/decisions.md
    title: Tagging GGUF
---

# Definition

Single shared Llama session; primary vs optional tagging GGUF bookmarks.

# Links

- Code: [`SharedLlamaInference.swift`](../../../Phathom/Phathom/Services/SharedLlamaInference.swift)
- Decisions: [2026-05-15 tagging GGUF](../../decisions.md#decision-log)
- Related: [withSession](./with-session.md) · [GGUF bookmark](./gguf-bookmark.md)
- Pitfalls: recall agentmemory tags `withSession`, `llama.cpp` (do not duplicate here)
