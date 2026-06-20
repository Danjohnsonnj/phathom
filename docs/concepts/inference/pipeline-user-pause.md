---
type: Glossary
title: PipelineUserPause
description: Global user pause flag; gates schedule* and foreground/BG processing.
tags: [inference, pipeline]
anchor: Phathom/Phathom/Services/BackgroundPipeline.swift
---

# Definition

Global user pause flag; gates **`schedule*`** and foreground/BG processing.

# Links

- Code: [`PipelineUserPause`](../../../Phathom/Phathom/Services/PipelineUserPause.swift) · [`BackgroundPipeline.swift`](../../../Phathom/Phathom/Services/BackgroundPipeline.swift)
- Decisions: [2026-05-27 Library Pause](../../decisions.md#decision-log)
- Related: [BackgroundPipeline](./background-pipeline.md)
- Pitfalls: recall agentmemory tags `pipeline` (do not duplicate here)
