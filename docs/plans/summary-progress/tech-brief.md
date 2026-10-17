---
type: TechBrief
title: "Summary progress tech brief"
description: Current architecture, verified findings, and proposed design.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17" }
---

# Tech brief - current state and gaps

## Current architecture (verified)

- `ProcessingStatus` — pending, scraping, embedding, summarizing, extracting, tagging, completed, failed (`Phathom/PhathomCore/Sources/PhathomCore/Enums.swift`).
- `BackgroundPipeline` — scrape → embed → analyze (summarize, tags, extracts) plus a media vision path (`Phathom/Phathom/Services/BackgroundPipeline.swift`).
- `PipelineMetrics` — prints per-stage wall time to the console (`[PhathomPipeline]`). It does not persist samples (`Phathom/Phathom/Services/PipelineMetrics.swift`).
- Library status UI — `ProcessingStatusBadge` is a text capsule on `ContentCardRow` and `GalleryListRow`. No progress bar.
- Settings — `@AppStorage` preferences already exist (`SettingsTab.swift`). Sections include AI models, Display, Library, and Data.

## Verified findings / gaps

1. Prompt budgets cap how much source the model sees. Decision 2026-05-02: summary uses the first ~12k characters, extracts ~8k, tags ~4k. Full-article word count is not linear with inference time past those caps (`docs/decisions.md`).
2. Summarize → tags → extracts share one Llama session and must keep KV reuse. A progress feature must observe that path, not split it.
3. No stored word count, token count, or duration on the item today. The average and the per-item length used for the estimate both need a home.
4. Embed is a status ("Ready to analyze") that can sit before analyze starts. Scrape depends on the network. Those stages are a poor fit for a length-based on-device average.

## Proposed architecture

Locked so far:

- One determinate bar for the analyze pass (summarize + extracts + tags). Fill is elapsed time divided by the estimated duration. The status chip can still name the current stage. Fetch and embed are outside the estimate.
- Estimate = the current model pair’s rate × capped source length. The cap is the summary prompt budget (~12k characters). The rate is that pair’s total analyze time divided by its capped characters.
- Web and notes contribute. Media uses the vision path and is excluded.
- The determinate bar appears only after three successful passes for the current pair. Earlier passes on that pair keep the status chip and still update it. Other pairs keep their own counts.
- Bar placement: library list (`GalleryListRow`) and Detail. The shipped capsule chip stays above a thin full-width track (text column only on the row; above the host and title on Detail). Canonical mock: `docs/plans/summary-progress/mocks/summary-progress-ad-chip-bar-a.html`. Do not port its CSS.
- Rate updates only after summary, extracts, and tags all complete. Failures are ignored. Paused idle time is excluded. A later successful retry counts once.
- Persistence: device settings only, one bucket per model pair. Identity is filename plus byte count for Primary, and the same for Tagging. Tagging identity equals Primary when no Tagging file is selected, Tagging falls back to Primary (`lastTaggingPreferredUsedPrimaryFallback`), or the tagging step does not run. The in-flight estimate uses the configured pair. The completed sample is stored on the pair that actually ran. Excluded from library backup. No schema change. There is no model-version field; do not use bookmark bytes or the formatted size string as the key.
- Overrun: determinate fill until elapsed time passes the estimate, then an indeterminate bar. The status chip stays.
- Settings: toggle defaults off, Display section. No remaining-time label; the chip names the stage.

Product behavior, the chip-above-track layout, and per-model-pair rates are locked. The implementation plan includes the pair key. Do not start code until that plan is approved.

## Hard invariants

- `SharedLlamaInference.withSession` stays serialized.
- KV reuse on summarize → tags → extracts stays intact.
- The progress bar does not gate or reorder pipeline work.
