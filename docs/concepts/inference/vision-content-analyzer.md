---
type: Glossary
title: VisionContentAnalyzer
description: VLM path for media via llama.cpp libmtmd (text GGUF + mmproj).
tags: [inference, pipeline, media]
anchor: Phathom/Phathom/Inference/VisionContentAnalyzer.swift
---

# Definition

VLM path for media via llama.cpp **`libmtmd`** (text GGUF + mmproj).

# Links

- Code: [`VisionContentAnalyzer.swift`](../../../Phathom/Phathom/Inference/VisionContentAnalyzer.swift)
- Decisions: [2026-05-24 media vision](../../decisions.md#decision-log)
- Related: [BackgroundPipeline](./background-pipeline.md) · [withSession](./with-session.md)
- Pitfalls: recall agentmemory tags `llama.cpp`, `pipeline` (do not duplicate here)
