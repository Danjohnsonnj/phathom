---
type: Glossary
title: GGUF bookmark
description: Security-scoped bookmark to user-selected model file (not copied into app sandbox).
tags: [inference, pipeline]
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:20:00Z" }
resource: Phathom/Phathom/Services/SharedLlamaInference.swift
sources:
  - id: decision-2026-05-02
    resource: docs/decisions.md
    title: GGUF bookmark
---

# Definition

Security-scoped bookmark to user-selected model file (not copied into app sandbox).

# Links

- Code: [`ModelManager`](../../../Phathom/Phathom/Services/ModelManager.swift) (bookmark storage) · [`SharedLlamaInference.swift`](../../../Phathom/Phathom/Services/SharedLlamaInference.swift)
- Decisions: [2026-05-02 bookmark](../../decisions.md#decision-log)
- Related: [SharedLlamaInference](./shared-llama-inference.md)
- Pitfalls: recall agentmemory tags `llama.cpp`, `xcframework` (do not duplicate here)
