# Media vision inference — v1 QA matrix (**shipped**)

> **Status:** **Shipped** (2026-05-24). **Authority:** [`docs/decisions.md`](../decisions.md) row **2026-05-24**, then **code** under `VisionContentAnalyzer`, `BackgroundPipeline`, and Settings vision section.
>
> **Audience:** Historical QA checklist only. Agents cold-start from **code + decisions**, not this file.

## Prerequisites

| Item | Action |
|------|--------|
| Build | Debug or Release on device |
| Vision pair | Settings → **Vision model** — matching text GGUF + mmproj (Smol or Qwen class VLM pair) |
| Test button | Vision **Test** succeeds before pipeline QA |
| Optional | Clear **Primary** to validate media-only gate (web should not analyze without primary) |

## Device matrix

Record **Pass / Fail / Skip** and one-line notes. Photo types: **A** general, **B** screenshot/text-heavy, **C** meme/social.

| ID | Scenario | Vision model | Steps | Expected |
|----|----------|--------------|-------|----------|
| D1 | New photo — happy path | ON | Add New → Photo → save | Stages: Preparing → **Analyzing photo** → Creating tags → **completed**; vision description in Detail **Source Content** (not header); Library teaser unchanged; **no Summary** section |
| D2 | Photo types | ON | D1 with A, B, C | Each completes; Source Content description mentions scene and/or visible text where relevant |
| D3 | No vision model | OFF | Add New → Photo → save | Fast **completed**; placeholder in Detail **Source Content** (not header); **no** Analyze again |
| D4 | Add New copy | ON / OFF | Photo mode footnote | ON: on-device Vision hint; OFF: Settings prompt for Vision model |
| D5 | Analyze again | ON | Completed photo → Detail → **Analyze again** | Clears Source Content description/tags; re-runs stages; **completed** again; still no Summary section |
| D6 | Library search | ON | After D1, search unique word from description | Item in matching results |
| D7 | Search tags | ON | If tags present, search tag name | Item found |
| D8 | Share extension | ON | Share image from Photos → open app | Same queue/complete as Add New (may need foreground) |
| D9 | Share degrade | OFF | Share image | Placeholder in **Source Content** + **completed**, no failure |
| D10 | Failed retry | ON | Provoke or use failed media row | Detail **Retry** enabled; re-queues or completes |
| D11 | Failed retry gate | OFF | Failed media (if any) | **Retry** disabled |
| D12 | Background / kill | ON | Save photo; background or kill during **Analyzing photo**; relaunch | Resumes or rewinds to Preparing — not stuck forever |
| D13 | Web gate | ON, Primary **off** | Save web URL + photo | Photo processes; web stays queued/embedding without primary |
| D14 | Archive in-flight | ON | Archive photo during analysis | No crash; processing stops sensibly |
| D15 | Cancel / thermal | ON | Cancel if UI exposes; or note thermal throttle | Graceful failed or pause — no corrupt store |
| D16 | Badge copy | ON | Watch Library chip during `summarizing` | **Analyzing photo** (not Generating summary) |
| D17 | Settings smoke | ON | Vision Test | Succeeds on device |
| D18 | No backfill | ON | Old pre-ship media rows | Unchanged until user taps Analyze again |

## Regression (web / note)

| ID | Scenario | Expected |
|----|----------|----------|
| R1 | Web + Primary ON | Unchanged scrape → summarize → tag flow |
| R2 | Note analyze | Unchanged |
| R3 | Reset processing queue | **Web only** — media in-flight not bulk-reset |

## Automated coverage (CI / simulator)

| Area | Tests | Status |
|------|--------|--------|
| ShareCapture queue | `shareCaptureInsertMediaItemQueuesEmbedding` | CI |
| Degrade | `mediaEmbeddingDegradesWithoutVisionModel` | CI |
| Drain gate | `embeddingQueueSkipsWebWithoutPrimaryWhenMediaReady` | CI |
| Revive | `reviveAbortedRewindsMediaSummarizingToEmbedding` | CI |
| Recovery | `ProcessingRecoveryMediaTests` | CI |
| Badge | `ProcessingStatusPresentationMediaTests` | CI |
| Prompt | `VisionContentAnalyzerTests` | CI |
| Search | `librarySearch_matchesMediaDescription` | CI |
| mediaStuck | `reviveMediaStuckWithoutVisionCompletesWithPlaceholder` (+ summarizing/tagging variants) | CI |

**Phase 5 automated:** `bash scripts/test-phathom.sh` on simulator (use `--grep media` / `--test <name>` for targeted runs; `bash scripts/test-phathom.sh --list` for identifiers). Device matrix (D1–D18) remains manual sign-off below.

## Sign-off

| Role | Date | Result |
|------|------|--------|
| Device QA (matrix above) | | Pending — physical iPhone |
| v1 automated (PhathomTests) | 2026-05-25 | **62/62 pass** (simulator) |
| v1 feature complete | | Blocked on device matrix |

**Known limits (v1):** No RAG embeddings; no OCR-first documents; no backfill; user-added tags cleared on Analyze again (same as web Summarize again).
