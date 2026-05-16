# Phathom

<p align="center">
  <img src="docs/assets/phathom-icon.png" alt="Phathom" width="128" />
</p>

**Phathom** is a **local-first iOS “personal brain”**: capture links, notes, and media into your own library, run **on-device** analysis with **Llama.cpp**, and (roadmap) chat over what you saved—without sending your content to the cloud.

## Product features

- **Capture** — Add items from the in-app **Add New** flow and the **`PhathomShare`** share extension (URLs, text, images). Web captures can be saved offline-first and finish when the network is back.
- **Library & detail** — Browse saved **Content** with filters, clear **processing status** (queued → fetch → summarize → tags, and related states), and open a **detail** view with summaries, tags, extracts, and **source** text or markdown where available.
- **Highlights & notes** — In detail **source**, select text to create a **highlight** (persisted in SwiftData); optional **per-highlight note**. Anchors are **UTF-16** ranges into stored **`sourceMarkdown`** (aligned with `SourceContentIndexer` / WKWebView `data-md-*` offsets).
- **On-device LLM** — After ingest, the pipeline runs **summarization**, **auto-tagging**, and **structured extracts** using a **primary GGUF** you choose in Settings. You can optionally pick a **second GGUF** used only for tagging (ingest + **Regenerate tags**); if it is missing or fails to load, tagging uses the primary model.
- **Privacy** — **SwiftData** on device only; no CloudKit/sync in the current design. See [`docs/decisions.md`](docs/decisions.md).
- **Archive & recovery** — **Archive** behaves like delete in the library, with **undo** and **Recently Deleted** under Settings (time-limited retention). See the product/decision notes in [`docs/product-brief.md`](docs/product-brief.md) and [`docs/decisions.md`](docs/decisions.md).
- **System integration** — **Spotlight** / **App Intents** are part of the planned surface area for making the library discoverable on-device (see Phase 2 hand-off).

**Not shipped yet (roadmap):** the **Chat** tab is still a placeholder; **RAG**-style conversational search over your library is Phase 3. See [`docs/handoff/phase-3-rag-chat.md`](docs/handoff/phase-3-rag-chat.md).

## Major functionality

| Area          | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ingest**    | Fetches and normalizes web pages (generic HTML uses a Readability-style **main content** pass for both plain **`rawText`** and optional **`sourceMarkdown`**). Specialized paths exist for some social hosts.                                                                                                                                                                                                                                                                                                                                                                |
| **Pipeline**  | **Background** tasks and foreground **drain** coordinate scraping, then **embedding** queue stages, then **Llama** passes—serialized so overlapping wakes don’t corrupt in-flight analysis.                                                                                                                                                                                                                                                                                                                                                                                  |
| **Inference** | **`SharedLlamaInference`** loads/unloads GGUF(s) inside a locked **`withSession`** (serialized — never concurrent dual-load). **`LlamaCppRuntime`** wraps vendored **`llama.xcframework`** (Metal on device, CPU on simulator). **Summarize** and **extracts** share **KV cache prefix reuse** (`llama_memory_seq_cp`) on the primary model in one session. **Tags** (`tagsFromDerived` from summary + extracts + highlights) run in a following **`taggingPreferred`** session that loads an optional tagging GGUF when set, otherwise reuses primary. Also enables Flash Attention (AUTO), **`offload_kqv`**, and tuned **`n_ubatch`**. See **Llama performance** below. |
| **Storage**   | **SwiftData** models for items, tags, **highlights** (with optional user notes), chat scaffolding, etc. **Embeddings** are not persisted yet (queue state only); RAG storage is future work.                                                                                                                                                                                                                                                                                                                                                                                  |

Deeper architecture and file map: [`docs/handoff/phase-2-pipeline.md`](docs/handoff/phase-2-pipeline.md).

## Requirements

- **Xcode** and **iOS SDK** matching the deployment target set in **`Phathom/Phathom.xcodeproj`** (open the project to see the current value).
- A **physical device** is recommended for realistic Llama performance (Neural Engine / GPU path). The **simulator** runs Llama **CPU-only** and is mainly useful for UI and light testing.
- **Supported run targets:** **iPhone 16 Pro or newer** (simulator or physical). Use an **iPhone 16 Pro** (or newer Pro-line) simulator in Xcode, or deploy to a real **iPhone 16 Pro or newer** for Metal-backed inference.

## Building the app

1. Clone the repository.
2. Open **`Phathom/Phathom.xcodeproj`** in Xcode.
3. Select the **Phathom** scheme. Set the run destination to an **iPhone 16 Pro or newer** simulator, or to a connected **iPhone 16 Pro or newer** device.
4. Build and run (**⌘R**).

**Command-line checks** (same targets the project expects):

```bash
bash scripts/build-phathom.sh all   # Simulator (preferred Pro-line sim) + generic iOS device build
```

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
- In **Settings**, pick a **primary** `.gguf` for summaries, extracts, Library semantic search, and related-item ranking. Optionally pick a **tagging** `.gguf` for auto-tags and **Regenerate tags** only; if unset or unreadable, tagging uses the primary file.
- Use **Select … from Files…** for each role. Phathom stores **security-scoped bookmarks** so weights can stay under **On My iPhone** (or similar); they are **not** copied into the app sandbox. Files must remain **locally available**; iCloud-only or evicted blobs can fail or stall background work.
- Prompts assume a **Llama 3–style chat template**; other families may run but are not officially supported in v1.

### Runtime behavior

- **Load / unload** are tied to **`SharedLlamaInference.withSession`**: the model is loaded for a pipeline or Settings test, then unloaded when the session ends (including error and cooperative cancel paths). Background **expiration** signals cancel and lets the session tear down cleanly—avoid parallel **unload** from task handlers.
- **Device:** `LlamaCppRuntime` sets **`n_gpu_layers = -1`** (GPU/ANE path). **Simulator:** **`n_gpu_layers = 0`** (CPU).

### Llama performance (article analyze)

Summarize and extract share one primary-model session with **article-first prompts** so the chat-templated article prefix is identical across tasks; the runtime **decodes that prefix once** into sequence 0, then **forks** it via **`llama_memory_seq_cp`** before decoding each task’s suffix. **Tagging** runs afterward in a separate session (optional second GGUF via **`taggingPreferred`** routing; **reload skipped** when the resolved path matches the already-loaded primary). Context creation also enables **Flash Attention (AUTO)**, **`offload_kqv`**, **`n_ubatch`** (default 1024), **`n_seq_max = 4`**, and **`kv_unified`** for the summarize/extract multi-sequence path.

### Optional warm-up

After a valid selection, the app may **warm** the model shortly after launch when thermals allow (see **`scheduleWarmFromPersistedSelection`** in code).

---

**Further reading:** [`docs/product-brief.md`](docs/product-brief.md) · [`docs/technical-brief.md`](docs/technical-brief.md) · [`docs/decisions.md`](docs/decisions.md)
