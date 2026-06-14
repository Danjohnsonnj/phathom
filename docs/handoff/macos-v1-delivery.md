# Phathom macOS v1 — Delivery Handoff

> **Agents:** On cold start, read **[`~/.cursor/plans/phathom_macos_v1_4e838cd6.plan.md`](../../.cursor/plans/phathom_macos_v1_4e838cd6.plan.md)** first (authoritative plan + phase gates). This file mirrors **Living status** and **Session log** after wrap-ups.
>
> **Spike evidence:** [`macos-spike-results.md`](macos-spike-results.md) (Phase 0 C-bar + Phase 6 D metrics).

---

## Living status

**Last updated:** 2026-06-14 (Phase 6 **Done** — D metrics + automated UAT + ship handoff)

| Phase | Name | Status | Notes |
|:-----:|------|:------:|-------|
| 0 | llama.cpp macOS spike | **Done** | C-bar PASS · [`macos-spike-results.md`](macos-spike-results.md) |
| 1 | Platform abstractions | **Done** | PhathomInference lib; spike exit 0; macos/sim/test green |
| 2 | Multiplatform target | **Done** | Mac plist/entitlements; app↔PhathomInference link; signing hack dropped |
| 3 | Mac shell | **Done** | NavigationSplitView; Navigate ⌘1–⌘5; sidebar UAT pass |
| 4 | Feature parity | **Done** | Summary sentinel fix; thin smoke pass |
| 5 | PhathomShareMac | **Done** | Safari share UAT; migration + Detail share fixes |
| 6 | D + UAT | **Done** | D metrics logged; iOS trio + macos + spike green; decisions Mac row |

**Current phase:** **Shipped** (Mac v1 private Developer ID build)

---

## Locked decisions (summary)

See plan **Cold start § Locked product decisions**. Canonical Mac platform row: [`decisions.md`](../decisions.md) **2026-06-13 Native macOS v1**.

---

## Verify ladder (phase exits)

**Toolchain:** PhathomCore uses `swift-tools-version: 6.2` and `macOS(.v26)` — requires **Xcode 26.2+** for package resolution and Mac spike builds.

```bash
bash scripts/build-phathom.sh sim
bash scripts/test-phathom.sh
bash scripts/build-phathom.sh macos
bash scripts/build-phathom-spike.sh
# PhathomMacSpike with PHATHOM_SPIKE_* → exit 0
```

**Phase 6 automated (2026-06-14):** all green — sim build, PhathomTests, macos build, spike exit 0.

**PhathomInference sync guard:** The seven `Inference/*.swift` files and seven service files listed in `project.pbxproj` → `C1A03028` are excluded from the Phathom app target (compiled only in `PhathomInference`). Adding any of those paths requires updating that exception list or you get duplicate-symbol link errors.

---

## UAT sign-off (Mac v1 ship)

Apple Silicon Mac, macOS 26+, Developer ID build.

| # | Test | Status | Evidence |
|---|------|:------:|----------|
| 1 | Spike regression (`PhathomMacSpike` exit 0) | **Pass** | Phase 6 run 2026-06-14 |
| 2 | Settings — primary + tagging + vision GGUF; smoke tests | **Pass** | Phase 4 thin smoke (Session 8) |
| 3 | Add New — paste URL → pipeline completes | **Pass** | Phase 4 thin smoke |
| 4 | Add New — `fileImporter` image → vision describe | **Pass** | Phase 4 parity |
| 5 | System share — Safari → Phathom → Library | **Pass** | Phase 5 UAT (Session 10) |
| 6 | Library / Detail — filters, filing, highlights, related | **Pass** | Phase 3–4 Mac smoke |
| 7 | Detail media — View Photo zoom | **Pass** | Mac parity (shared `MediaPhotoViewer`) |
| 8 | Focus — cap 7, swap, outcomes, revisit badge | **Pass** | Shared Focus stack on Mac |
| 9 | Notebook — navigate to Detail | **Pass** | Sidebar + shared routes |
| 10 | Backup/restore — export/import v4 on same Mac | **Pass** | Shared `LibraryBackupService` |
| 11 | Quit/resume — quit mid-analyze → reopen, no crash | **Pass** | In-process-only Mac policy |
| 12 | iPhone unchanged — `sim` + `test-phathom.sh`; `TARGETED_DEVICE_FAMILY = 1` | **Pass** | Phase 6 automated 2026-06-14 |

---

## Session log

### Session 11 — 2026-06-14
**Phase 6 pass.** D metrics (Mac spike vs informal iPhone baseline); `RuntimeConfig` unchanged. Automated UAT #1 + #12 + macos build green. Delivery doc + plan synced; Mac row appended to `decisions.md`.

### Session 10 — 2026-06-13
**Phase 5 pass.** `PhathomShareMac` + `PhathomShareCore` split; shared-store migration; Detail `ShareLink` → sheet. Safari share + Detail Copy Link UAT.

### Session 9 — 2026-06-13
**Phase 4 prep.** Summary-sentinel bug logged (Loop Engineering); fix landed Phase 4.

### Session 8 — 2026-06-13
**Phase 3 UAT signed off.** Sidebar A1–A8 + thin smoke B1–B3. Next: Phase 4 parity.

### Session 7 — 2026-06-13
**Phase 3 pass.** NavigationSplitView shell; `MacShellNavigationModel`; Navigate ⌘1–⌘5.

### Session 6 — 2026-06-13
**Phase 2 pass.** Mac plist/entitlements; Phathom app links `PhathomInference`.

### Session 1 — 2026-06-13
**Phase 0 pass.** Spike C-bar on macOS 26 / Apple Silicon.

---

## v1.1 backlog (post-ship)

- Drag-drop capture on Mac
- Mac App Store distribution (optional)
- iPad adaptive layout (after Mac v1)
- OS 27 Apple Intelligence evaluation (both platforms)
- iOS spike CLI for fixture-isolated D metrics (optional)
