# Phathom

<p align="center">
  <img src="docs/assets/phathom-icon.png" alt="Phathom" width="128" />
</p>

**Phathom** is a **local-first iOS “personal brain”**: capture links, notes, and media into your own library, run **on-device** analysis with **Llama.cpp**, and (roadmap) chat over what you saved—without sending your content to the cloud.

**For agents:** start at **[`AGENTS.md`](AGENTS.md)** (build, verify, invariants). Domain glossary: **[`CONTEXT.md`](CONTEXT.md)**.

## Product features

- **Capture**: Add items from the in-app **Add New** flow and the **PhathomShare** share extension (URLs, text, images). Web captures can be saved offline-first and finish when the network is back.
- **Library & detail**: Browse saved content with filters (**type**, **read status**, **category**), clear **processing status** (queued → fetch → summarize → tags, and related states), and open a **detail** view with summaries, tags, category (optional edit separate from filing), extracts, and **source** text or markdown where available.
- **Highlights & notes**: In detail **source**, select text to create a **highlight**; optional **per-highlight note**.
- **On-device LLM**: After ingest, the pipeline runs **summarization**, **auto-tagging**, and **structured extracts** using a **primary GGUF** you choose in Settings. You can optionally pick a **second GGUF** used only for tagging (ingest + **Regenerate tags**); if it is missing or fails to load, tagging uses the primary model.
- **Privacy**: All data stays on device; no CloudKit or sync in the current design.
- **Library backup / restore**: Settings exports non-archived items as versioned JSON for recovery after reinstall or device migration.
- **Archive & recovery**: **Archive** behaves like delete in the library, with **undo** and **Recently Deleted** under Settings (time-limited retention).
- **System integration**: **Spotlight** search and an **Open in Phathom** App Intent surface library items system-wide.

## Roadmap (coming soon)

| Track              | Doc                                                                    |
| ------------------ | ---------------------------------------------------------------------- |
| **RAG / Chat tab** | [`docs/handoff/phase-3-rag-chat.md`](docs/handoff/phase-3-rag-chat.md) |

The **Chat** tab for RAG-grounded conversations is not shipped yet. See the hand-off above for scope and design.

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
bash scripts/build-phathom.sh sim   # Routine: iOS Simulator (Pro-first destination list)
# bash scripts/build-phathom.sh device   # generic iphoneos — device signing / device-only checks
# bash scripts/build-phathom.sh all      # sim then device — xcframework refresh / pre-release only

bash scripts/test-phathom.sh            # PhathomTests on simulator (--list / --grep / --test)
```

The repo expects a vendored framework at:

**`Phathom/vendor/llama/llama.xcframework`**

If that folder is missing in your checkout, you need a compatible **llama.cpp** build packaged as an **XCFramework** (device + simulator slices). This repo includes a helper script that **copies** a framework from another local checkout (paths inside the script are editable):

```bash
bash scripts/setup-llama-xcframework.sh
```

The script’s comments point at a typical source (`intrai-llama`); you can also produce **`llama.xcframework`** from upstream **llama.cpp** using the same packaging approach your team uses for iOS static libraries + headers. **Bridging expectation:** statically link **`llama.xcframework`**, **`import llama`** from Swift, toolchain links **`-lc++`** — no alternate Swift wrappers. More detail: [AGENTS.md](AGENTS.md).

## Llama.cpp: setup and use

### Weights (GGUF)

- The app **does not ship** a model. You obtain a **`.gguf`** file (for example Llama 3.x instruct variants) from a source you trust.
- In **Settings**, pick a **primary** `.gguf` for summaries, extracts, Library semantic search, and related-item ranking. Optionally pick a **tagging** `.gguf` for auto-tags and **Regenerate tags** only; if unset or unreadable, tagging uses the primary file.
- Use **Select … from Files…** for each role. Phathom stores **security-scoped bookmarks** so weights can stay under **On My iPhone** (or similar); they are **not** copied into the app sandbox. Files must remain **locally available**; iCloud-only or evicted blobs can fail or stall background work.
- Prompts assume a **Llama 3–style chat template**; other families may run but are not officially supported in v1.

### Runtime behavior

- The model loads for a pipeline pass or Settings test, then unloads when the session ends (including error and cancel paths).
- **Device:** GPU/ANE path enabled. **Simulator:** CPU only.
