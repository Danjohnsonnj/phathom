---
type: Lesson
title: "Summary progress lessons"
description: Curated toolkit of reusable gotchas and verify outcomes.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17" }
---

# Lessons (reusable toolkit; accreted across sessions)

## Device UAT confirmed the bar states

- Context: Checking analysis progress on a phone after simulator tests.
- Lesson: Three finished articles teach the pair. The next shows the chip plus bar on the library row and Detail. Past the estimate, the bar slides. The bar goes away when the item finishes.
- Evidence: Device UAT 2026-10-17, user report, success.
- Crystallize?: no

## Model identity is the file, not a version

- Context: Keying analyze-time rates by the user’s GGUF choices.
- Lesson: There is no model-version field. Use filename plus byte count. Tagging falls back to Primary when its file is missing or fails to load.
- Evidence: `ModelManager.selectionDisplayState` uses `lastPathComponent`. `SharedLlamaInference.ensureLoadedLocked` sets `lastTaggingPreferredUsedPrimaryFallback`.
- Crystallize?: no

## Article length is capped before inference

- Context: Estimating analyze time from source length.
- Lesson: Summary, extract, and tag prompts only send the first ~12k, ~8k, and ~4k characters. Past those caps, extra words should not increase the estimate.
- Evidence: `docs/decisions.md` row 2026-05-02 (tag/extract prompt budgets). Not re-measured in this session.
- Crystallize?: no
