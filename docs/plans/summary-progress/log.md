# Effort log

## 2026-10-17 - Session 1: Device UAT passed

- Happened: User ran the feature on a device with Analysis progress on.
- Verified: App launched. Display toggle is present and works. Three article runs finished with the chip only. The next run showed a progress bar on the library row and in Detail, and the chip updated with the stage. A later run tracked the estimate. A longer article passed the estimate and the bar became indeterminate. Bars disappeared when processing finished. User reported other behavior still correct.
- Learned: The three-sample gate, chip-plus-bar layout, and overrun state match the lock on a real device.
- Overwrote: HANDOFF phase and next action; product-state shipped row; README feature line.

## 2026-10-17 - Session 1: Model pairs locked

- Happened: Each Primary + Tagging pair keeps its own rate, keyed by filename and byte count. No Tagging file, Tagging fallback, or skipped tags use Primary for the tagging half. The bar estimates the configured pair; the sample is stored on the pair that ran. Vision stays out.
- Verified: `ModelManager` identifies a picked file by `lastPathComponent` and has no version field. Tagging fallback is `lastTaggingPreferredUsedPrimaryFallback`.
- Learned: A formatted size string is a display value. The key uses the file byte count.
- Overwrote: product-brief decisions 3, 4, 7, and 12; tech-brief rate and persistence; HANDOFF next action.

## 2026-10-17 - Session 1: Layout locked

- Happened: Locked the explore mock as the reference. Chip sits above a thin full-width track on the library text column and above the Detail host and title.
- Verified: User said lock it after reviewing the mock.
- Learned: none new.
- Overwrote: product-brief decision 11; tech-brief bar placement; mock page label; HANDOFF phase and next action; phases.

## 2026-10-17 - Session 1: Explore mock

- Happened: Added `docs/plans/summary-progress/mocks/summary-progress-ad-chip-bar-a.html`. Six frames: library and Detail, each at summary (~35%), extracts (~70%), and tags (indeterminate). Archive mocks were not edited.
- Verified: Opened in the browser. Library row shows the capsule chip with the track under the text column. Detail shows the same cluster above the host and title. No remaining-time label.
- Learned: The archived library badge is an old uppercase style. The mock follows the shipped capsule chip instead.
- Overwrote: HANDOFF phase and next action; product-brief later note.

## 2026-10-17 - Session 1: Discovery complete

- Happened: No remaining-time label. Chip names the stage. All product decisions are locked. Next step is a design mock before build.
- Verified: none.
- Learned: none new.
- Overwrote: product-brief decisions; tech-brief proposed architecture; phases; HANDOFF phase and next action.

## 2026-10-17 - Session 1: Settings locked

- Happened: Toggle defaults off and lives in the Display section.
- Verified: none.
- Learned: none new.
- Overwrote: product-brief boundaries and decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Overrun locked

- Happened: The bar fills against the estimate. Past that, it becomes indeterminate and the status chip stays.
- Verified: none.
- Learned: none new.
- Overwrote: product-brief decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Storage locked

- Happened: Rate is two device-setting totals (analyze time and capped characters). Rate = time / characters. Not in library backup. No schema change.
- Verified: none.
- Learned: none new.
- Overwrote: product-brief decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Samples locked

- Happened: Only a finished summary + extracts + tags pass updates the rate. Failures do not. Pause idle time does not. A retry that succeeds counts once.
- Verified: Library backup encodes item fields explicitly (`LibraryBackupService`), so a device-speed rate is not part of that export today.
- Learned: none new.
- Overwrote: product-brief decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Surfaces locked

- Happened: Bar on the library list and on Detail. Status chip stays beside the bar so the current stage is visible. Recently Deleted and Related items stay chip-only. Design mock of the chip-plus-bar pairing is deferred.
- Verified: none.
- Learned: User described the bar as covering two phases; the locked pass is still three stages (summary, extracts, tags). Chip labels those three.
- Overwrote: product-brief goal and decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Cold start locked

- Happened: The status chip stays until three successful web or note analyze passes. The fourth pass is the first determinate bar. Those first three still update the rate.
- Verified: none.
- Learned: The library list row is `GalleryListRow`. The status chip also appears on Detail, Recently Deleted (`ContentCardRow`), and Related items. Notebook rows do not show processing status.
- Overwrote: product-brief goal and decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Kinds locked

- Happened: Web articles and notes show the bar and share one rate. Photos keep the status chip and do not update the rate.
- Verified: none.
- Learned: none new.
- Overwrote: product-brief decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Length model locked

- Happened: Chose one rate scaled by capped source length. Estimate = rate × characters the analyze prompts will send, capped at the summary budget. Each finished pass updates the rate.
- Verified: none.
- Learned: Web and notes share the text analyze path. Media uses a separate vision path, so it cannot share a character rate.
- Overwrote: product-brief decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Stages locked

- Happened: Chose one progress bar for the on-device analyze pass (summary, extracts, tags). Fetch and embed stay on the status chip. Fill is elapsed time against the estimate.
- Verified: none.
- Learned: none new.
- Overwrote: product-brief goal and decisions; tech-brief proposed architecture; HANDOFF next action.

## 2026-10-17 - Session 1: Discovery start

- Happened: Opened the effort at `docs/plans/summary-progress/`. Mapped status chips, pipeline stages, and console-only `PipelineMetrics`. No code changes.
- Verified: none (discovery only).
- Learned: Stage timings already exist as console logs. Summary, tag, and extract prompts are character-capped, so raw article length is not a linear predictor past those caps.
- Overwrote: none (initial write).
