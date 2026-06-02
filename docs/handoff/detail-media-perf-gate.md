# Detail media image — Phase 1 gate + Phase 3 SLA

**Profiling:** `-MediaImageProfiling` or `phathom.mediaImageProfiling`. Filter `[Phathom.Media]`.

**Trace reading (2026-06-01+):** one line per event in Console (`Logger`); `print` only in `#if DEBUG`. Filter `[Phathom.Media]`. `cache_hit` at most once per item per Detail `onAppear` generation.

**View Photo presentation gate:** **PASS** — [`detail-media-perf-resume.md`](detail-media-perf-resume.md#view-photo-presentation-gate).

**Metrics gate:** **PASS** (2026-06-01) — single-line traces; bounded `cache_hit`.

**Phase 3 slice (chosen):** **1024px / 0.72 library JPEG** + **ImageIO decode cap = `libraryStorageMaxDimension`** (was 1200 storage / 1600 decode cap). New captures only; legacy rows unchanged.

**Shipped (uncommitted on branch):** fetch off-main, NSCache, prewarm, **load coalescing**, **library storage JPEG** (new captures), metrics.

## Phase 1 gate

| Field | Value |
|-------|--------|
| Legacy UUID | `4A447DA5-5114-4A4F-857C-51636AC6169A` |
| New capture UUID (best) | `C6ED4EB8-154A-4870-BC03-A4C6D481F230` |
| Outlier UUID | `7397008F-7B24-4B67-BDAC-2F8D0956FF9C` |
| **Verdict** | **`both`** — fault + decode |

## Dedupe verification (2026-06-01 device)

| Check | Result |
|-------|--------|
| Single load per metric (after halving pairs) | **Pass** — one fault/decode/task per cold open |
| Raw log line pairs | **Misleading** — dual emit, not dual load |

## Phase 3 SLA — existing 929 KB item

| Metric | ms (one line) |
|--------|---------------|
| `thumbnail_fault` | ~1039 |
| `decode_off_main` | ~24147 |
| `detail_task` | ~25553 |
| **Pass ≤3s** | **Fail** |

## New-capture SLA (library storage JPEG)

| UUID | bytes | decode ms | detail_task ms | ≤3s |
|------|------:|----------:|---------------:|:---:|
| `C6ED4EB8-…` | 639693 | ~5308 | ~6217 | **Fail** |
| `7397008F-…` | 807616 | ~45089 | ~105033 | **Fail** (outlier) |

| Field | Value |
|-------|--------|
| Median wall clock (user) | _re-run ×3 if needed_ |
| **Pass / fail** | **Fail** (best ~6.2s task time) |

## Automated regression

| Date | Result |
|------|--------|
| 2026-06-01 follow-up | `build-phathom.sh sim` + `--grep coalesce|library storage|media` — **passed** (local) |

## Gate 3 — SLA re-measure (user, device)

**Status:** **PASS** (2026-06-01) — new capture with **1024 / 0.72** library JPEG + aligned ImageIO decode cap; `detail_task` ≤3s.

**Profiling:** `-MediaImageProfiling`. Kill app → cold Library → Detail.

| Item | UUID | Pass `detail_task` ≤3s |
|------|------|:----------------------:|
| New capture (1024/0.72) | _(user-verified)_ | **Pass** |
| Legacy row | `4A447DA5-5114-4A4F-857C-51636AC6169A` | Fail expected (no backfill) |

If new captures regress above 3s, next slice: decode-at-ingest display bitmap.
