# macOS llama.cpp spike results

**Status:** **PASS** — Phase 0 exit gate met (2026-06-13)

**Gate:** PhathomMacSpike exit 0 on Apple Silicon Mac, macOS 26, required before Phase 1.

---

## Environment

| Field | Value |
|-------|-------|
| Mac model | Apple Silicon (arm64) |
| macOS version | 26.x (build host) |
| Xcode version | 26.x |
| Primary GGUF | `Qwen2.5-3B-Instruct.Q4_K_M.gguf` (iCloud llm-models) |
| Vision GGUF + mmproj | `Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf` + `mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf` |
| Date | 2026-06-13 |

---

## C-bar results

| Step | Pass | Wall time | Peak memory | Notes |
|------|:----:|-----------|-------------|-------|
| 1 Load GGUF | ✅ | 9.12 s | 451.2 MB | quick_test 108 chars |
| 2 Full analyze (`article.md`) | ✅ | 3.09 s | 460.3 MB | summary=1 extracts=5 |
| 3 Vision describe (`sample.jpg`) | ✅ | 3.73 s | 218.5 MB | profile=capable, 97 chars |

**Overall:** **PASS**

---

## D optimization (optional, not go/no-go)

**Phase 6 run:** 2026-06-14 · MacBook Pro M4 · macOS 26.5.1 · Xcode 26.5 · same GGUF/mmproj as C-bar.

| Step | iPhone 16 Pro | Mac (Phase 6) | Delta / notes |
|------|---------------|---------------|---------------|
| 2 Analyze (`article.md`) | No iOS spike CLI — informal **~25–30 s** load+analyze wall on same **Qwen2.5-3B Q4** class in full app pipeline ([decisions 2026-05-03](../decisions.md)) | **4.40 s** · **451.5 MB** peak · summary=3 extracts=5 | Mac **~6×** faster on fixture-isolated analyze; shared `RuntimeConfig` defaults sufficient |
| 3 Vision (`sample.jpg`) | No fixture baseline logged | **3.73 s** · **451.5 MB** peak · profile=capable | Vision wall unchanged vs Phase 0 C-bar |

**RuntimeConfig:** Kept shared **`RuntimeConfig.default`** (`contextWindow` 8192, `physicalBatchSize` 1024). Mac peak ~452 MB — no macOS-specific override; iPhone 8 GB constraint unchanged.

---

## Failure / replan

If FAIL: log errors here; **stop** Mac v1 track; schedule replan (OS 27 / Apple Intelligence on both platforms).

---

## Implementation notes (Phase 0)

- `llama.xcframework` now includes **macos-arm64** slice (Metal, deployment target 26.0).
- **PhathomInference** static library (`Phathom/Inference/**` + ModelManager, SharedLlamaInference, VisionModelSmokeTest, helpers) — **PhathomMacSpike** links it; app compiles inference inline until **Phase 2** [app↔lib link](macos-v1-delivery.md) (separate module + sync-group exclusions; not `PRODUCT_MODULE_NAME = Phathom` on both targets).
- Run: `bash scripts/build-phathom-spike.sh` then set `PHATHOM_SPIKE_GGUF`, `PHATHOM_SPIKE_VISION_GGUF`, `PHATHOM_SPIKE_MMPROJ`.
