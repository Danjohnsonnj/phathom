---
type: Phases
title: "Summary progress phases"
description: Phase objectives and verify steps.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17" }
---

# Phases

## Phase 1 - Discovery

- Lock product decisions in the product brief.
- Verify: product-brief open decisions are none. Done 2026-10-17.

## Phase 2 - Design mock

- Static mock of the status chip plus progress bar on the library row and on Detail, including the indeterminate overrun state.
- Verify: user locked `docs/plans/summary-progress/mocks/summary-progress-ad-chip-bar-a.html` on 2026-10-17. Chip above a thin track. Do not port the CSS.

## Phase 3 - Build

- Persist the rate in device settings, time finished web and note analyze passes, and show the bar on the library list and Detail when the Display toggle is on.
- Verify: unit tests for the rate update and ETA math; simulator build. Device UAT passed 2026-10-17 (three teaching runs, then bar on list and Detail, a later accurate run, overrun indeterminate, bar cleared on completion).
