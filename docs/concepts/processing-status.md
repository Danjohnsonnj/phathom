---
type: Glossary
title: ProcessingStatus
description: Pipeline state: `pending` → scrape/embed → summarize/tag/extract → `completed` or `failed`.
status: stable
generated: { by: "cursor-agent", at: "2026-10-17T17:20:00Z" }
resource: Phathom/PhathomCore/Sources/PhathomCore/Enums.swift
sources:
  - id: decision-log
    resource: docs/decisions.md
    title: Granular processing sub-states
---
# Definition

Pipeline state: `pending` → scrape/embed → summarize/tag/extract → `completed` or `failed`.

# Links

- Code: [`Enums.swift`](../../Phathom/PhathomCore/Sources/PhathomCore/Enums.swift)
- Decisions: [granular sub-states](../decisions.md#decision-log)
