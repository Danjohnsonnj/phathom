---
type: Invariant
title: withSession
description: Serialized GGUF access; no parallel Llama calls.
tags: [inference, pipeline, invariant]
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:20:00Z" }
resource: Phathom/Phathom/Services/SharedLlamaInference.swift
sources:
  - id: decision-2026-05-02
    resource: docs/decisions.md
    title: Serialized session
---

# Definition

Serialized GGUF access via **`SharedLlamaInference`** + **`AsyncLock`**; no parallel Llama calls.

# Links

- Code: [`SharedLlamaInference.swift`](../../../Phathom/Phathom/Services/SharedLlamaInference.swift)
- Decisions: [2026-05-02 serialized session](../../decisions.md#decision-log)
- Related: [KV cache reuse](./kv-cache-reuse.md) · [SharedLlamaInference](./shared-llama-inference.md)
- Pitfalls: recall agentmemory tags `llama.cpp`, `n_batch`, `withSession` (do not duplicate here)
