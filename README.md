# Phathom

<p align="center">
  <img src="docs/assets/phathom-icon.png" alt="Phathom" width="128" />
</p>

**Phathom** is a **local-first iOS “personal brain”**: capture links, notes, and media into your own library, run **on-device** analysis with **Llama.cpp**, and (roadmap) chat over what you saved—without sending your content to the cloud.

## Product features

- **Capture** — Add items from the in-app **Add New** flow and the **`PhathomShare`** share extension (URLs, text, images). Web captures can be saved offline-first and finish when the network is back.
- **Library & detail** — Browse saved **Content** with filters, clear **processing status** (queued → fetch → summarize → tags, and related states), and open a **detail** view with summaries, tags, extracts, and **source** text or markdown where available.
- **On-device LLM** — After ingest, the pipeline runs **summarization**, **auto-tagging**, and **structured extracts** using a **GGUF** model you choose in Settings (not bundled with the app).
- **Privacy** — **SwiftData** on device only; no CloudKit/sync in the current design. See [`docs/decisions.md`](docs/decisions.md).
- **Archive & recovery** — **Archive** behaves like delete in the library, with **undo** and **Recently Deleted** under Settings (time-limited retention). See the product/decision notes in [`docs/product-brief.md`](docs/product-brief.md) and [`docs/decisions.md`](docs/decisions.md).
- **System integration** — **Spotlight** / **App Intents** are part of the planned surface area for making the library discoverable on-device (see Phase 2 hand-off).

**Not shipped yet (roadmap):** the **Chat** tab is still a placeholder; **RAG**-style conversational search over your library is Phase 3. See [`docs/handoff/phase-3-rag-chat.md`](docs/handoff/phase-3-rag-chat.md).

## Major functionality

| Area          | What it does                                                                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ingest**    | Fetches and normalizes web pages (generic HTML uses a Readability-style **main content** pass for both plain **`rawText`** and optional **`sourceMarkdown`**). Specialized paths exist for some social hosts. |
| **Pipeline**  | A **`BGAppRefreshTask`** drains the web scrape queue; LLM analysis runs as a foreground **drain** (Metal) or, when the user taps **Continue in background**, as a snapshot CPU pass inside a **`BGContinuedProcessingTask`** with a system Live Activity. All three lanes share one **`PipelineWorkGate`** lock so overlapping wakes never corrupt in-flight analysis. |
| **Inference** | **`SharedLlamaInference`** loads/unloads the GGUF inside a locked **`withSession(backend:)`**; **`LlamaCppRuntime`** wraps vendored **`llama.xcframework`**. Foreground uses **Metal** (`n_gpu_layers = -1`); the user-initiated background lane uses **CPU** (`n_gpu_layers = 0`, smaller `n_ubatch`) because iPhone Background GPU is not available today. Article analyze uses **KV cache prefix reuse** (`llama_memory_seq_cp`): one prefill of the article for summarize → tags → extracts, plus Flash Attention (AUTO), **`offload_kqv`**, and tuned **`n_ubatch`**. See **Llama performance** below. |
| **Storage**   | **SwiftData** models for items, tags, chat scaffolding, etc. **Embeddings** are not persisted yet (queue state only); RAG storage is future work.                                                             |

Deeper architecture and file map: [`docs/handoff/phase-2-pipeline.md`](docs/handoff/phase-2-pipeline.md).

## Requirements

- **Xcode** and **iOS SDK** matching the deployment target set in **`Phathom/Phathom.xcodeproj`** (open the project to see the current value).
- A **physical device** is recommended for realistic Llama performance (Neural Engine / GPU path). The **simulator** runs Llama **CPU-only** and is mainly useful for UI and light testing.
- Optimized for an iPhone 16 Pro or better.

## Building the app

1. Clone the repository.
2. Open **`Phathom/Phathom.xcodeproj`** in Xcode.
3. Select the **Phathom** scheme and a suitable **iPhone** simulator or device.
4. Build and run (**⌘R**).

The repo expects a vendored framework at:

**`Phathom/vendor/llama/llama.xcframework`**

If that folder is missing in your checkout, you need a compatible **llama.cpp** build packaged as an **XCFramework** (device + simulator slices). This repo includes a helper script that **copies** a framework from another local checkout (paths inside the script are editable):

```bash
bash scripts/setup-llama-xcframework.sh
```

The script’s comments point at a typical source (`intrai-llama`); you can also produce **`llama.xcframework`** from upstream **llama.cpp** using the same packaging approach your team uses for iOS static libraries + headers. Integration rules (no third-party Swift wrappers, link **`import llama`**, **`-lc++`**) are documented in [`docs/handoff/phase-2-pipeline.md`](docs/handoff/phase-2-pipeline.md).

## Llama.cpp: setup and use

### Weights (GGUF)

- The app **does not ship** a model. You obtain a **`.gguf`** file (for example Llama 3.x instruct variants) from a source you trust.
- In **Settings**, use **Select model from Files…** to pick the file. Phathom stores a **security-scoped bookmark** so the file can stay under **On My iPhone** (or similar); it is **not** copied into the app sandbox. The file must remain **locally available**; iCloud-only or evicted files can fail or stall background work.
- Prompts assume a **Llama 3–style chat template**; other families may run but are not officially supported in v1.

### Runtime behavior

- **Load / unload** are tied to **`SharedLlamaInference.withSession(backend:)`**: the model is loaded for a pipeline or Settings test, then unloaded when the session ends (including error and cooperative cancel paths). Background **expiration** signals cancel and lets the session tear down cleanly—avoid parallel **unload** from task handlers. The app additionally calls **`forceUnloadIfIdle()`** on `scenePhase != .active` so a Metal context is never held across a background transition.
- **Foreground (device):** `LlamaCppRuntime` sets **`n_gpu_layers = -1`** (GPU/ANE path). **Background lane** (user-initiated `BGContinuedProcessingTask`) and **simulator**: **`n_gpu_layers = 0`** (CPU). Tap **Continue in background** in the Library banner to keep processing while the app is closed; the OS shows a Live Activity for progress and cancellation.

### Llama performance (article analyze)

Summarize, tag, and extract run in one session with **article-first prompts** so the chat-templated article prefix is identical across tasks; the runtime **decodes that prefix once** into sequence 0, then **forks** it per task via **`llama_memory_seq_cp`** before decoding each task’s instruction suffix—avoiding two extra full prefills of the article. Context creation also enables **Flash Attention (AUTO)**, **`offload_kqv`**, **`n_ubatch`** (default 1024), **`n_seq_max = 4`**, and **`kv_unified`** for the multi-sequence path.

**Measured (informal):** same web article, **iPhone 16 Pro**, app **force-quit then cold launch** (model load + full analyze pass), wall time dropped from **~1 minute to ~30 seconds**. Actual numbers depend on GGUF size/quant, article length, thermals, and whether the fast path runs or the pipeline falls back to sequential decode (e.g. context pressure). Use Xcode console lines prefixed **`[PhathomPipeline]`** (`summarize`, `tags_llm`, `extracts_llm`, `load_model`) to profile your setup.

### Optional warm-up

After a valid selection, the app may **warm** the model shortly after launch when thermals allow (see **`scheduleWarmFromPersistedSelection`** in code).

---

**Further reading:** [`docs/product-brief.md`](docs/product-brief.md) · [`docs/technical-brief.md`](docs/technical-brief.md) · [`docs/decisions.md`](docs/decisions.md)
