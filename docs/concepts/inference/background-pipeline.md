---
type: Glossary
title: BackgroundPipeline
description: Orchestrates scrape → embed → analyze and media vision path.
tags: [inference, pipeline]
anchor: Phathom/Phathom/Services/BackgroundPipeline.swift
---

# Definition

Orchestrates scrape → embed → analyze (summarize, tags, extracts) and media vision path.

# Links

- Code: [`BackgroundPipeline.swift`](../../../Phathom/Phathom/Services/BackgroundPipeline.swift)
- Decisions: [pipeline rows](../../decisions.md#active-invariants-index)
- Related: [withSession](./with-session.md) · [PipelineUserPause](./pipeline-user-pause.md) · [VisionContentAnalyzer](./vision-content-analyzer.md)
- Pitfalls: recall agentmemory tags `pipeline`, `PipelineMetrics` (do not duplicate here)
