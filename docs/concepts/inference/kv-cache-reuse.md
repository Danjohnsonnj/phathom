---
type: Glossary
title: KV cache reuse
description: Article prefix decoded once; per-task seq fork via llama_memory_seq_cp.
tags: [inference, pipeline, invariant]
anchor: Phathom/Phathom/Inference/LlamaCppRuntime.swift
---

# Definition

Article prefix decoded once; per-task seq fork via **`llama_memory_seq_cp`**.

# Links

- Code: [`BackgroundPipeline.swift`](../../../Phathom/Phathom/Services/BackgroundPipeline.swift) · [`LlamaCppRuntime.swift`](../../../Phathom/Phathom/Inference/LlamaCppRuntime.swift)
- Decisions: [2026-05-03 KV reuse](../../decisions.md#decision-log)
- Related: [withSession](./with-session.md) · [BackgroundPipeline](./background-pipeline.md)
- Pitfalls: recall agentmemory tags `KV-cache`, `llama.cpp` (do not duplicate here)
