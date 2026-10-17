---
type: ProductBrief
title: "Summary progress product brief"
description: Goals, rationale, non-goals, and boundaries.
status: draft
generated: { by: "cursor-agent", at: "2026-10-17" }
---

# Product brief - Summary progress

## Background

Newly added library items move through scrape, embed, then on-device analyze (summary, extracts, tags). The library row shows a text status chip ("Generating summary", "Creating tags", and so on). There is no estimate of how long analyze will take, and stage timings are logged to the console only.

## Goal

When a Settings option is on, and this device has three successful passes recorded, a processing web article or note shows one progress bar for the on-device analyze pass (summary, extracts, and tags) on the library list and on Detail. The existing status chip stays above the bar so the current stage is visible. Until three successes, the chip shows alone. The bar fills from elapsed time against an estimate of that pass. The estimate comes from the running rate for the current Primary and Tagging model pair: average analyze time per character of source text the model will actually read, capped at the summary prompt budget. A new item’s estimate is that pair’s rate times its capped length. After each successful analyze pass, that item updates the pair that actually ran. Fetch and embed keep the existing status chip.

## Rationale

On-device summary and tagging vary with article length and device speed. A fixed spinner does not tell the user whether to wait or leave the row. A length-scaled average gives a moving expectation without a server.

## Non-goals

- A Chat or RAG surface.
- Changing how summaries or tags are generated.
- A historical analytics screen of past timings.

## Boundaries

- Always: the Settings toggle defaults off and lives in Display. The bar is an estimate, not a promise.
- Ask first: schema changes.
- Never: parallel Llama sessions; blocking the pipeline on UI updates.

## Success criteria

- With the toggle on, after three successful passes, the next web article or note shows a determinate progress bar on the library list and on Detail while analyze runs, with the status chip still visible and no remaining-time label.
- Before three successes, and for photos, the chip shows as it does today.
- The bar’s duration scales with capped source length using the rate for the current model pair.
- A finished pass updates the rate. A failure does not.
- With the toggle off, the list and Detail look as they do today.

## Decisions

1. **Stages.** The clock and the bar cover summarizing, extracting, and tagging as one pass. Fetch and embed stay on the status chip. Locked 2026-10-17.
2. **Length model.** One rate, scaled by capped source length (characters the analyze prompts will send, capped at the summary budget). Each finished pass updates that rate. Locked 2026-10-17.
3. **Kinds.** Web articles and notes show the bar and share the rate for the model pair that ran. Photos keep the status chip and do not update any rate. Locked 2026-10-17.
4. **Cold start.** The status chip stays until three successful web or note analyze passes have updated the rate for the current model pair. The fourth pass on that pair is the first to show a determinate bar. A different pair starts its own count. Locked 2026-10-17.
5. **Surfaces.** The bar appears on the library list and on Detail, and the status chip stays on both so the current stage (summary, extracts, or tags) remains visible. Recently Deleted and Related items keep the chip only. Locked 2026-10-17.
6. **Samples.** Only a pass that finishes summary, extracts, and tags updates the rate. Failures do not. Pause time does not. A retry that then succeeds counts once. Locked 2026-10-17.
7. **Storage.** Each model pair keeps its own device-setting totals: analyze time, capped characters, and sample count. The rate is time divided by characters. Pairs are not part of library backup and do not change the database. Locked 2026-10-17.
8. **Overrun.** The bar fills against the estimate. Once elapsed time passes it, the bar becomes indeterminate and the status chip stays. Locked 2026-10-17.
9. **Settings.** The toggle defaults off and lives in the Display section. Locked 2026-10-17.
10. **Label.** The bar has no remaining-time text. The status chip names the stage. Locked 2026-10-17.
11. **Layout.** Chip above a thin full-width track. On the library row the track spans the text column only, and the date stays hidden while processing. On Detail the cluster sits above the host and title. Canonical mock: `docs/plans/summary-progress/mocks/summary-progress-ad-chip-bar-a.html`. Archive mocks were not changed. Locked 2026-10-17.
12. **Model pair.** A pair is the Primary file plus the Tagging file, each identified by filename and byte count. If no Tagging file is selected, Tagging falls back to Primary, or tags never run, the tagging half is Primary. The bar estimates with the pair configured at the start. The finished pass is stored on the pair that actually ran. Switching back to an earlier pair reuses that pair’s rate. Vision files are not part of the key. Locked 2026-10-17.

## Device UAT

Passed 2026-10-17 on a real device, toggle on:

- App launched. The Display toggle is present and works.
- Three finished articles stayed on the status chip.
- The next article showed the bar on the library row and in Detail. The chip kept naming the stage and updated as the stage changed.
- A following article tracked the estimate.
- A longer article ran past the estimate and the bar became indeterminate.
- The bar left the row and Detail when processing finished.
- Other behavior looked unchanged.

## Open decisions

None.
