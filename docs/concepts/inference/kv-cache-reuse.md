---
type: Invariant
title: KV cache reuse
description: Article prefix decoded once; per-task seq fork via llama_memory_seq_cp.
tags: [inference, pipeline, invariant]
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:20:00Z" }
resource: Phathom/Phathom/Inference/LlamaCppRuntime.swift
sources:
  - id: decision-2026-05-03
    resource: docs/decisions.md
    title: KV reuse
---

# Definition

Article prefix decoded once; per-task seq fork via **`llama_memory_seq_cp`**.

# Links

- Code: [`BackgroundPipeline.swift`](../../../Phathom/Phathom/Services/BackgroundPipeline.swift) · [`LlamaCppRuntime.swift`](../../../Phathom/Phathom/Inference/LlamaCppRuntime.swift)
- Decisions: [2026-05-03 KV reuse](../../decisions.md#decision-log)
- Related: [withSession](./with-session.md) · [BackgroundPipeline](./background-pipeline.md)
- Pitfalls: recall agentmemory tags `KV-cache`, `llama.cpp` (do not duplicate here)
