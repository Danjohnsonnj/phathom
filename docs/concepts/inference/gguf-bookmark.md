---
type: Glossary
title: GGUF bookmark
description: Security-scoped bookmark to user-selected model file (not copied into app sandbox).
tags: [inference, pipeline]
anchor: Phathom/Phathom/Services/SharedLlamaInference.swift
---

# Definition

Security-scoped bookmark to user-selected model file (not copied into app sandbox).

# Links

- Code: [`ModelManager`](../../../Phathom/Phathom/Services/ModelManager.swift) (bookmark storage) · [`SharedLlamaInference.swift`](../../../Phathom/Phathom/Services/SharedLlamaInference.swift)
- Decisions: [2026-05-02 bookmark](../../decisions.md#decision-log)
- Related: [SharedLlamaInference](./shared-llama-inference.md)
- Pitfalls: recall agentmemory tags `llama.cpp`, `xcframework` (do not duplicate here)
