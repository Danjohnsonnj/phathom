# Phase 0 — Vision VLM spike (handoff)

> **Status:** DEBUG harness + **dual-profile** spike (`compact` vs `capable`) on-device. Validates llama.cpp + **libmtmd** before Phase 1 production bookmark / pipeline wiring.

## Goal

Prove on a **physical iPhone** that vendored **llama.cpp + libmtmd** can load a vision-capable **text GGUF + mmproj**, describe a JPEG, and return usable caption text for future `mediaDescription` (Phase 2+).

## Prerequisites

1. xcframework rebuilt with mtmd when bumping upstream:
   ```bash
   bash scripts/rebuild-llama-xcframework-with-mtmd.sh
   ```
2. **Debug** build on device (simulator CPU-only — slow/OOM for larger VLMs).
3. Matching **text GGUF + mmproj** pair per Hugging Face / ggml-org release notes.

### Code touchpoints

| Piece | Path |
|-------|------|
| mtmd xcframework rebuild | [`scripts/rebuild-llama-xcframework-with-mtmd.sh`](../../scripts/rebuild-llama-xcframework-with-mtmd.sh) |
| Spike runtime | [`LlamaVisionSpike.swift`](../../Phathom/Phathom/Inference/LlamaVisionSpike.swift) |
| Profile heuristics + tunables | [`VisionSpikeProfileResolver.swift`](../../Phathom/Phathom/Services/VisionSpikeProfileResolver.swift) |
| Exclusive unload / lock | [`SharedLlamaInference.withVisionSpikeSession`](../../Phathom/Phathom/Services/SharedLlamaInference.swift) |
| DEBUG Settings UI | [`VisionSpikeSettingsSection.swift`](../../Phathom/Phathom/Views/Settings/VisionSpikeSettingsSection.swift) |
| Bookmarks | [`VisionSpikeStorage.swift`](../../Phathom/Phathom/Services/VisionSpikeStorage.swift) |

## Run spike (in app)

1. Settings → **Vision spike (Phase 0)** — DEBUG builds only.
2. **Pick** text GGUF and **mmproj** (same document picker pattern as AI models — security-scoped bookmarks).
3. **Profile:** **Auto**, **Compact**, or **Capable** (persisted).
   - **Auto** resolves from GGUF filename + file size (~1.2 GiB heuristic when name ambiguous).
   - **Compact**: max image side **1600** px — tuned for smaller VLMs (e.g. SmolVLM class).
   - **Capable**: max image side **768** px initially, tighter `image_max_tokens` — tuned for heavier VLMs (e.g. **Qwen2.5-VL**).
4. Choose test photo → **Run vision describe**.
5. Record **Load / Eval / Generate / Total** from the inline report plus short quality note.

**Memory isolation:** the spike calls `SharedLlamaInference.withVisionSpikeSession`, which **unloads** the user’s primary pipeline GGUF before load and restores warm behavior afterward — avoids false Jetsam from **two GGUFs** resident.

### Harness checklist

- [ ] **Pick** for text GGUF → system picker; caption shows readable filename.
- [ ] Same for **mmproj**.
- [ ] Failed imports show Settings **Import failed** alert pattern (where wired).
- [ ] Run completes → report shows profile, GPU projector line, estimated sequence tokens when available.
- [ ] Force-quit → reopen Settings → Run without re-picking (bookmark relaunch smoke test).

Repeat per candidate model pair where possible.

## Pass criteria (Phase 0 gate)

| Check | Pass |
|-------|------|
| `Vision: yes` in report | ✓ |
| Non-empty caption on a general photo | ✓ |
| No Jetsam on iPhone 16 Pro-class (document if borderline) | ✓ |
| Wall time documented (subjective for background UX) | ✓ |

Gate approval still follows the **media image inference** plan phases before promoting to production bookmarks / pipeline.

## Troubleshooting

| Symptom | Likely cause | What to try |
|---------|---------------|-------------|
| `EXC_BAD_ACCESS` in `mtmd_init_from_file` (low addr) | Mismatched mmproj / Metal FA / warmup quirks | Confirm **paired** GGUF + mmproj; spike uses **GPU projector**, **FA off**, **warmup=false** |
| Stall + `ggml_aligned_malloc` … huge CPU alloc in Xcode log | **CPU** projector / encode (`use_gpu=false` path) — multi-GB graphs on Qwen class | Spike now forces **Metal projector** (`use_gpu=true`); stay on capable profile |
| Process killed / code 9 (memory) | Two models loaded (**primary warmup + spike**) | Fixed by `withVisionSpikeSession`; retest isolated run |
| “Vision spike timed out” | Rare native hang beyond 600 s guard | Retry; smaller capable photo; Instruments memory trace |
| `mtmd_init_from_file returned nil` | Pairing / GGUF incompatibility | Re-download matching mmproj revision |

Quantitative breakdown: Xcode console + Instruments — **Metal System Trace** / **Allocations**. Report lines include **estimated sequence tokens** after `mtmd_tokenize`.

## Profile table (effective tunables)

| Profile | Typical models | Max image px (long side) | `image_max_tokens` (cap) | Spike `n_ctx` |
|---------|----------------|--------------------------|--------------------------|---------------|
| **compact** | Smol-class, small GGUF heuristics | 1600 | metadata default (`nil`) | 4096 |
| **capable** | Qwen2.5-VL + similar | 768 → retry **512** on first failure | 1024 → retry **768** | 2048 |

Capable path performs **one** automatic tightened retry with smaller JPEG + caps.

## Candidate log

| Candidate | Text GGUF | mmproj | Device | Photo type | Profile | Total s | Notes |
|-----------|-----------|--------|--------|------------|---------|---------|-------|
| A | | | | | Auto | | |
| B | | | | | Auto | | |

## After spike

Finalize [`docs/decisions.md`](../decisions.md) **2026-05-24** row with measured defaults (family pairing, realistic max pixels, gate decision).

**Phase 1+** (bookmark, `ModelManager`-style persistence, pipeline) remains out of this handoff — see workspace media inference plan doc.
