---
type: Glossary
title: VisionContentAnalyzer
description: VLM path for media via llama.cpp libmtmd (text GGUF + mmproj).
tags: [inference, pipeline, media]
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:20:00Z" }
resource: Phathom/Phathom/Inference/VisionContentAnalyzer.swift
sources:
  - id: decision-2026-05-24
    resource: docs/decisions.md
    title: Media vision
---

# Definition

VLM path for media via llama.cpp **`libmtmd`** (text GGUF + mmproj).

# Links

- Code: [`VisionContentAnalyzer.swift`](../../../Phathom/Phathom/Inference/VisionContentAnalyzer.swift)
- Decisions: [2026-05-24 media vision](../../decisions.md#decision-log)
- Related: [BackgroundPipeline](./background-pipeline.md) · [withSession](./with-session.md)
- Pitfalls: recall agentmemory tags `llama.cpp`, `pipeline` (do not duplicate here)
