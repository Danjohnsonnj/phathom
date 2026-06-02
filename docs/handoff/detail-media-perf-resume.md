# Handoff: Detail media perf — resume investigation

**Date:** 2026-06-01  
**Goal:** cold Library → Detail hero + View Photo **≤3s** (media items).  
**SLA status:** **PASS** for new captures (Gate 3, 1024/0.72 slice). Legacy rows still slow unless re-ingested or backfill added.

---

## Read first (cold start)

| Priority | Doc / code |
|----------|------------|
| 1 | This file |
| 2 | [`detail-media-perf-gate.md`](detail-media-perf-gate.md) — tables + protocols |
| 3 | Plan (attached in prior session): `detail_media_follow-up` — slices 1–3 **implemented locally, uncommitted** |
| 4 | [`MediaDisplayImageLoader.swift`](../../Phathom/Phathom/Helpers/MediaDisplayImageLoader.swift), [`MediaDisplayImageLoadCoordinator.swift`](../../Phathom/Phathom/Helpers/MediaDisplayImageLoadCoordinator.swift) |
| 5 | [`MediaImageEncoding.swift`](../../Phathom/PhathomCore/Sources/PhathomCore/MediaImageEncoding.swift) — `normalizedJPEGForLibraryStorage` (1024px / 0.72) |

**Profiling:** `-MediaImageProfiling` on device; filter `[Phathom.Media]`.

---

## View Photo presentation gate

**Status:** **PASS** (2026-06-01) — presentation + `PhotoZoomScrollView` zoom (Gate 1 + 1b).

Run **without** profiling first. **Fail** if any step needs app-switcher nudge.

| Step | Expected |
|------|----------|
| Library → media **A** → View Photo (first tap) | Image + Done immediately |
| Done → View Photo again (same Detail) | OK |
| Pop Library → **A** → View Photo | OK |
| Library → **B** → View Photo | OK |
| Pop Library → **A** → View Photo | OK |
| Notebook or Recently Deleted → media Detail → View Photo | OK |
| Optional: cold launch → View Photo | OK |

---

## Git / workspace state

- **Base on `main`:** `7573355` (Phase1: ImageIO hero + tap path).
- **Follow-up work:** **uncommitted** — new Helpers, `LibraryDetailRoute`, `MediaImageEncoding` library profile, tests, handoff docs. Run `git status` before continuing.
- **Do not** edit plan files in `.cursor/plans/` unless user asks.

---

## What shipped (follow-up, uncommitted)

| Piece | Purpose |
|-------|---------|
| `MediaDisplayImageLoadCoordinator` | Coalesce prewarm + Detail `loadDisplayImage` per UUID |
| Generation bump on `DetailView.invalidateMediaImageCache` | Drop stale in-flight results |
| `MediaImageLoadMetrics` | `print` + `Logger`; fixed `elapsedMilliseconds` |
| `normalizedJPEGForLibraryStorage` | New captures only — Add New + Share extension |
| `LibraryDetailRoute` | Prewarm on navigation |
| Tests | `MediaDisplayImageLoaderCoalesceTests`, `MediaImageEncodingLibraryStorageTests` |

**Not done:** disk cache, `externalStorage`, Notebook prewarm, Library `ThumbnailView` ImageIO, backfill existing rows.

---

## Device trace (user, 2026-06-01)

### How to read paired log lines

Every metric line is emitted **twice** in Xcode console: `print` **and** `os.Logger` in [`MediaImageLoadMetrics`](../../Phathom/Phathom/Helpers/MediaImageLoadMetrics.swift). **Identical ms on adjacent lines = one event**, not two loads.

`profiling ON` ×2 at launch = same dual-emit (or double app init in debug — check if harmful).

### Per-item summary (use **one** line per metric)

| UUID (short) | `thumbnailData.count` | `thumbnail_fault` ms | `decode_off_main` ms | `detail_task` ms | Notes |
|--------------|----------------------:|-------------------:|---------------------:|-----------------:|-------|
| `4A447DA5-…` | **929312** (legacy) | **~1039** | **~24147** (~24s) | **~25553** (~26s) | Pre–library-storage row; decode-bound |
| `7397008F-…` | **807616** | **~59862** (~60s) | **~45089** (~45s) | **~105033** (~105s) | **Outlier** — treat separately; possible cold DB / debugger / first fault |
| `C6ED4EB8-…` | **639693** | **~842** | **~5308** (~5.3s) | **~6217** (~6.2s) | **Best new capture**; library storage helped size; **still >3s SLA** |

### Dedupe verdict

- After halving paired lines: **one** fault + **one** decode + **one** detail_task per cold open → **coalescing likely OK**.
- Do **not** use raw line count as duplicate-load proof until logging is single-channel.

### `cache_hit` spam

Many `cache_hit` lines per item = `loadDisplayImage` entered repeatedly while UIImage already cached (SwiftUI `.task` / body refresh). Cheap path but noisy; consider log-once-per-navigation in a future pass.

### SLA

| Cohort | Median wall clock (user) | Pass ≤3s? |
|--------|--------------------------|-----------|
| Existing 929 KB | _not recorded separately_ | **Fail** (~26s `detail_task`) |
| New capture (C6ED…) | _fill if re-run_ | **Fail** (~6.2s `detail_task`) |

**Gate:** still **`both`** (fault + decode); ingest shrink helped **bytes** (~640 KB vs 929 KB) but **decode ~5s** remains blocker.

---

## Conclusions for next session

1. **Commit or review** uncommitted follow-up diff before more changes.
2. **Logging hygiene:** remove duplicate `print`+`Logger` (or DEBUG print only) so device traces are readable; throttle `cache_hit` logs.
3. **SLA gap (~6s → ≤3s):** library 1200/0.78 not enough alone. Candidates (pick one vertical slice):
   - **Decode at ingest** — store display-sized bitmap bytes (or pre-decoded) so Detail only memcopies
   - **Tighter library profile** — e.g. 1024px / 0.72 after one device tune
   - **Disk decode cache** (Phase 4) — helps repeat cold open, not first unless written at ingest
   - **Profile ImageIO** — verify subsample cap matches screen; ensure not falling back to full `UIImage(data:)`
4. **Investigate `7397008F` outlier** — 60s fault on ~808 KB suggests environmental (debugger attached, first launch migration), not steady-state; reproduce once without debugger.
5. **Optional:** lazy backfill for legacy rows — user previously chose **new captures only**; re-ask if 929 KB row must improve without re-ingest.

---

## Suggested next commands

```bash
# Verify
bash scripts/build-phathom.sh sim
bash scripts/test-phathom.sh --grep "coalesce|library storage|media"

# Device
# Scheme → -MediaImageProfiling → Run on device
# Kill app → cold Library → Detail on C6ED4EB8-… (new capture)
```

---

## Out of scope (unless user expands)

- Vision / pipeline changes
- Notebook / Recently Deleted prewarm
- RAG / Chat

---

## Agentmemory / issues

- Consider GitHub issue: "Detail media cold open >3s after library storage JPEG" with trace above if tracking externally.
- No schema change required for logging-only fixes.
