---
type: Glossary
title: SharedLlamaInference
description: Single shared Llama session; primary vs optional tagging GGUF bookmarks.
tags: [inference, pipeline]
anchor: Phathom/Phathom/Services/SharedLlamaInference.swift
---

# Definition

Single shared Llama session; primary vs optional tagging GGUF bookmarks.

# Links

- Code: [`SharedLlamaInference.swift`](../../../Phathom/Phathom/Services/SharedLlamaInference.swift)
- Decisions: [2026-05-15 tagging GGUF](../../decisions.md#decision-log)
- Related: [withSession](./with-session.md) · [GGUF bookmark](./gguf-bookmark.md)
- Pitfalls: recall agentmemory tags `withSession`, `llama.cpp` (do not duplicate here)
