---
type: Glossary
title: withSession
description: Serialized GGUF access; no parallel Llama calls.
tags: [inference, pipeline, invariant]
anchor: Phathom/Phathom/Services/SharedLlamaInference.swift
---

# Definition

Serialized GGUF access via **`SharedLlamaInference`** + **`AsyncLock`**; no parallel Llama calls.

# Links

- Code: [`SharedLlamaInference.swift`](../../../Phathom/Phathom/Services/SharedLlamaInference.swift)
- Decisions: [2026-05-02 serialized session](../../decisions.md#decision-log)
- Related: [KV cache reuse](./kv-cache-reuse.md) · [SharedLlamaInference](./shared-llama-inference.md)
- Pitfalls: recall agentmemory tags `llama.cpp`, `n_batch`, `withSession` (do not duplicate here)
