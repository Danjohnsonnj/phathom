# Phase 2 Hand-off: Background Pipeline + Llama.cpp Integration (Skeleton — Finalize After Phase 1)

> **Status**: This is a detailed skeleton. Sections marked `[TBD after Phase 1]` will be filled in once Phase 1 is complete, including exact file paths, patterns observed, and any schema adjustments. The AI engine decision has been **finalized** — Llama.cpp is the sole engine.

## Project Snapshot

**Phathom** is a local-only iOS personal brain app. Phase 1 built the UI shell — a TabView with Library (list + detail), Chat (placeholder), Add New, and Settings tabs, backed by a complete SwiftData schema with seed data.

- **Platform**: iOS 18+, Swift 5, SwiftUI, SwiftData
- **Storage**: Local-only — no CloudKit
- **Bundle ID**: `com.phathom.Phathom`
- **AI engine**: **Llama.cpp** (sole engine — see decision rationale below)

Read before starting:
- [docs/decisions.md](../decisions.md) — all prior decisions
- [docs/handoff/phase-1-ui-shell.md](phase-1-ui-shell.md) — what Phase 1 built
- [docs/product-brief.md](../product-brief.md) — product vision
- [docs/technical-brief.md](../technical-brief.md) — reference architecture (BG processing, RAG pipeline)

---

## AI Engine Decision: Llama.cpp Only

**Decision**: Llama.cpp is the sole AI engine for all phases. Apple FoundationModels is not used.

**Rationale** (documented in full in [docs/decisions.md](../decisions.md)):

1. **Direct experience**: FoundationModels crashed consistently after a few exchanges in a prior chatbot project. Extensive debugging yielded no fix. Llama.cpp replacement worked immediately and has been stable under extended use.
2. **4,096 token hard limit**: FoundationModels has a total context window of 4,096 tokens (input + output + history). For Phathom's summarization of long articles and multi-turn RAG chat, this is unworkable.
3. **Beta instability (as of May 2026)**: `EXC_BAD_ACCESS` on init, `dyld` symbol errors between betas, `@Generable` refusal regressions after OS updates, guardrail false positives on legitimate content (survival, cooking, etc.), intermittent `assetsUnavailable` errors.
4. **Device restriction**: FoundationModels requires Apple Intelligence (A17 Pro+, iPhone 15 Pro or later). Would require a full Llama.cpp fallback path anyway for older devices — doubling the integration surface for no benefit.
5. **~3B model**: Apple's on-device model is estimated at ~3B parameters, significantly less capable than available 7-8B GGUF models for summarization and reasoning quality.

**Model delivery**: The user provides GGUF model files based on recommendations shown in the app's Settings/setup flow. Models are stored locally and can be changed at any time for experimentation with new options. No models are bundled with the app.

---

## What Exists After Phase 1

`[TBD after Phase 1 — update this section with actual file tree, model paths, and any deviations from the Phase 1 spec]`

Expected state:
- SwiftData models: `ContentItem`, `Tag`, `ChatThread`, `ChatMessage` in `Phathom/Phathom/Models/`
- TabView shell with Library, Chat, Add New, Settings tabs
- Library screen with filter pills, card rows, thumbnail fallback, processing badges
- Detail screen with hero, AI summary, tags, extracts, actions
- Seed data populating 4 items on first launch
- No real AI or background processing — all summary/tag/extract data is hardcoded in seed

---

## Scope and Deliverables

Phase 2 replaces stubbed data with real AI-generated content through background processing. Three sub-tasks:

### 2A. Llama.cpp Integration + Model Management

Set up the inference service, model selection UI, and prompt templates.

### 2B. Background Pipeline

Wire `BGTaskScheduler` to scrape, embed, summarize, tag, and extract — writing results back to the SwiftData fields the UI already reads.

### 2C. Spotlight Integration

Index completed items into system Spotlight search with deep links back into the app.

---

## 2A. Llama.cpp Integration

### Swift Package

Use `mattt/llama.swift` — a semantically versioned Swift Package that wraps the official llama.cpp XCFramework. It auto-tracks upstream releases and supports iOS 16+.

```swift
// In Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/mattt/llama.swift", .upToNextMajor(from: "2.8722.0"))
]
```

This re-exports the llama.cpp C API directly. You call `llama_model_load_from_file`, `llama_init_from_model`, etc. For a higher-level Swift wrapper, `pgorzelany/swift-llama-cpp` (zero open issues, last updated April 2026) provides `LlamaService` with `AsyncSequence` token streaming — evaluate both and pick whichever fits the codebase better.

### Model Storage and Selection

Models are **not bundled**. The user places GGUF files on-device and selects them in Settings.

```
Phathom/Phathom/
├── Services/
│   ├── LlamaService.swift        # Model loading, inference, memory management
│   └── ModelManager.swift         # Discovers available models, persists user selection
├── Views/Settings/
│   └── ModelPickerView.swift      # File picker / list of discovered models
```

**Model discovery**: scan the app's Documents directory (and optionally a shared App Group container) for `*.gguf` files. Display them in Settings with file name and size. Persist the selected model path in `UserDefaults`.

**Recommended models to suggest in the UI** (not bundled — user downloads these):
- General use: `Llama-3.1-8B-Instruct-Q4_K_M.gguf` (~4.5 GB) — strong instruction-following, good summarization
- Lightweight: `Llama-3.2-3B-Instruct-Q4_K_M.gguf` (~1.8 GB) — faster, lower quality, good for testing
- Quality: `Gemma-2-9B-Instruct-Q4_K_M.gguf` (~5.5 GB) — strong reasoning and extraction

### Tricky Part: Model Lifecycle in Background Tasks

The model must be loaded into memory before inference and unloaded after to avoid holding ~2-4 GB of RAM while idle. Background tasks have strict memory limits.

```swift
class LlamaService {
    private var model: OpaquePointer?   // llama_model *
    private var context: OpaquePointer? // llama_context *
    private let modelURL: URL

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    func loadModel() throws {
        var params = llama_model_default_params()
        #if targetEnvironment(simulator)
        params.n_gpu_layers = 0
        #else
        params.n_gpu_layers = 99  // offload all layers to Metal GPU
        #endif

        model = llama_model_load_from_file(modelURL.path, params)
        guard model != nil else { throw LlamaError.modelLoadFailed }
    }

    func createContext(contextSize: UInt32 = 4096) throws {
        guard let model else { throw LlamaError.modelNotLoaded }
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = contextSize
        ctxParams.n_batch = 512
        context = llama_init_from_model(model, ctxParams)
        guard context != nil else { throw LlamaError.contextCreationFailed }
    }

    func unload() {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
        self.context = nil
        self.model = nil
    }

    deinit { unload() }
}
```

**Key pattern for BG tasks**: `loadModel()` at start of task, run inference, `unload()` before `setTaskCompleted`. Never keep the model resident between background wakes.

### Tricky Part: Prompt Templates for Structured Output

Phathom needs three distinct outputs from the same article text. Run them as separate inference calls within the same model-loaded session (avoids reloading the model 3 times per item).

**Summarization prompt**:
```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You are a concise summarizer. Given an article, produce exactly 3-5 bullet points capturing the key ideas. Output ONLY a JSON array of strings, no other text.
<|eot_id|><|start_header_id|>user<|end_header_id|>
{articleText}
<|eot_id|><|start_header_id|>assistant<|end_header_id|>
```

Expected output: `["Bullet one", "Bullet two", "Bullet three"]`

**Tagging prompt**:
```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You are a content tagger. Given an article, produce 3-8 lowercase topic tags. Output ONLY a JSON array of strings, no other text.
<|eot_id|><|start_header_id|>user<|end_header_id|>
{articleText}
<|eot_id|><|start_header_id|>assistant<|end_header_id|>
```

Expected output: `["urban planning", "sustainability", "architecture"]`

**Extraction prompt**:
```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You extract the 3-5 most notable facts, statistics, or actionable items from content. Output ONLY a JSON array of objects with "label" and "value" keys, no other text.
<|eot_id|><|start_header_id|>user<|end_header_id|>
{articleText}
<|eot_id|><|start_header_id|>assistant<|end_header_id|>
```

Expected output: `[{"label": "Carbon Reduction Target", "value": "~45%"}]`

**JSON parsing**: the model may produce markdown fences or preamble text before the JSON. Strip everything before the first `[` and after the last `]` before decoding. Have a fallback that sets the field to nil (not `.failed`) if parsing fails — the item is still `.completed` with partial data rather than stuck.

**Prompt format note**: The templates above use Llama-3's chat format. If the user selects a different model family (Gemma, Mistral, etc.), the chat template differs. For v1, support Llama-3 format only and document this. A future enhancement could detect the model family from GGUF metadata and switch templates.

### Settings UI — Model Setup Flow

The Settings tab (currently a placeholder from Phase 1) needs:

1. **Model section**: shows currently selected model name + file size, or "No model selected"
2. **"Select Model" button**: opens a file picker or lists `*.gguf` files found in the Documents directory
3. **Setup instructions**: brief text explaining where to get models and how to transfer them to the device (Files app → Phathom folder, or AirDrop)
4. **Recommended models list**: show the 3 suggestions above with Hugging Face links (as tappable URLs)
5. **Test button**: runs a short inference ("Summarize: The quick brown fox...") to verify the model loads and generates, shows result or error

---

## 2B. Background Pipeline

### Architecture

```
Capture (Add tab)
    → SwiftData write (status: .pending)
    → BGAppRefreshTask picks up (.pending → .scraping → .embedding)
    → BGProcessingTask picks up (.embedding → .summarizing → .tagging → .completed)
    → UI observes SwiftData changes via @Query and updates automatically
```

### BGTaskScheduler Registration

Register two task identifiers in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`:
- `com.phathom.ingest`
- `com.phathom.analyze`

### Task Registration and Scheduling

```swift
import BackgroundTasks

@main
struct PhathomApp: App {
    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.phathom.ingest",
            using: nil
        ) { task in
            handleIngest(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.phathom.analyze",
            using: nil
        ) { task in
            handleAnalyze(task: task as! BGProcessingTask)
        }
    }

    func scheduleIngest() {
        let request = BGAppRefreshTaskRequest(identifier: "com.phathom.ingest")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func scheduleAnalyze() {
        let request = BGProcessingTaskRequest(identifier: "com.phathom.analyze")
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

### Tricky Part: Analyze Task with Llama.cpp Model Lifecycle

```swift
func handleAnalyze(task: BGProcessingTask) {
    let context = ModelContext(sharedModelContainer)

    // Check that a model is configured
    guard let modelPath = UserDefaults.standard.string(forKey: "selectedModelPath"),
          FileManager.default.fileExists(atPath: modelPath) else {
        task.setTaskCompleted(success: false)
        return
    }

    var descriptor = FetchDescriptor<ContentItem>(
        predicate: #Predicate { $0.processingStatus != "completed" && $0.processingStatus != "failed" }
    )
    descriptor.fetchLimit = 1

    guard let item = try? context.fetch(descriptor).first else {
        task.setTaskCompleted(success: true)
        scheduleAnalyze()
        return
    }

    var isCancelled = false
    task.expirationHandler = {
        isCancelled = true
        item.processingStatus = ProcessingStatus.pending.rawValue
        item.processingDetail = "Paused — will resume when resources available"
        try? context.save()
    }

    Task {
        let llama = LlamaService(modelURL: URL(fileURLWithPath: modelPath))

        do {
            // Load model once for all three inference calls
            try llama.loadModel()
            try llama.createContext()

            // Stage 1: Summarize
            if !isCancelled {
                item.processingStatus = ProcessingStatus.summarizing.rawValue
                item.processingDetail = "Generating summary..."
                try context.save()

                let bullets = try await llama.generateSummary(text: item.rawText ?? "")
                item.encodeSummaryBullets(bullets)
                try context.save()
            }

            // Stage 2: Tag
            if !isCancelled {
                item.processingStatus = ProcessingStatus.tagging.rawValue
                item.processingDetail = "Auto-tagging..."
                try context.save()

                let tagNames = try await llama.generateTags(text: item.rawText ?? "")
                for name in tagNames {
                    let tagDescriptor = FetchDescriptor<Tag>(
                        predicate: #Predicate { $0.name == name }
                    )
                    let existing = try? context.fetch(tagDescriptor).first
                    let tag = existing ?? Tag(name: name)
                    if existing == nil { context.insert(tag) }
                    if !item.tags.contains(where: { $0.name == tag.name }) {
                        item.tags.append(tag)
                    }
                }
                try context.save()
            }

            // Stage 3: Extract
            if !isCancelled {
                item.processingDetail = "Extracting key information..."
                try context.save()

                let extractItems = try await llama.generateExtracts(text: item.rawText ?? "")
                item.encodeExtracts(extractItems)
            }

            // Done
            if !isCancelled {
                item.processingStatus = ProcessingStatus.completed.rawValue
                item.processingDetail = nil
                try context.save()
            }

            llama.unload()
            task.setTaskCompleted(success: !isCancelled)

        } catch {
            llama.unload()
            item.processingStatus = ProcessingStatus.failed.rawValue
            item.failureReason = error.localizedDescription
            try? context.save()
            task.setTaskCompleted(success: false)
        }

        scheduleAnalyze()
    }
}
```

**Critical**: call `llama.unload()` in both success and error paths. Leaking the model in a background task will cause iOS to terminate the app aggressively.

### Ingest Task — Web Scraping

The `com.phathom.ingest` BGAppRefreshTask (~30s budget) handles:

1. Fetch items where `processingStatus == .pending` and `contentKind == .web`
2. For each (2-3 max per burst):
   - Scrape the URL for `rawText` (use `URLSession` + basic HTML parsing, or `WebKit` snapshot)
   - Extract OG image URL from `<meta property="og:image">` → download → store as `thumbnailData`
   - Extract `displayHost` if not already set
   - Update status to `.embedding`
   - Create `NLEmbedding` vectors for the text chunks (store location TBD — see open question below)
3. Save and schedule the analyze task

**Open question for this phase**: Where to store embedding vectors. Options:
- A new `TextChunk` SwiftData model with a `[Float]` embedding field
- An external binary file per item (more performant for vector math)
- ObjectBox vector database (adds a dependency)

`[TBD after Phase 1 — decide vector storage approach based on expected corpus size and Phase 3 retrieval needs. Can defer embedding storage entirely to Phase 3 if the ingest task scope needs trimming.]`

### Thermal and Power Management

```swift
import Foundation

class ThermalMonitor {
    static let shared = ThermalMonitor()

    var shouldThrottle: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }

    func startMonitoring(onThrottle: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            if self.shouldThrottle {
                onThrottle()
            }
        }
    }
}
```

Integrate into both BG task handlers: check `ThermalMonitor.shared.shouldThrottle` before starting each item. If throttled, unload the model, complete the task early, and re-schedule.

---

## 2C. Spotlight Integration

After any item reaches `.completed`, index it:

```swift
import CoreSpotlight

extension ContentItem {
    func indexInSpotlight() {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = title
        attrs.contentDescription = decodedSummaryBullets.first
        attrs.keywords = tags.map(\.name)
        if let data = thumbnailData {
            attrs.thumbnailData = data
        }

        let item = CSSearchableItem(
            uniqueIdentifier: id.uuidString,
            domainIdentifier: "com.phathom.library",
            attributeSet: attrs
        )
        CSSearchableIndex.default().indexSearchableItems([item])
    }
}
```

### Deep Link via AppIntent

```swift
import AppIntents

struct OpenItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Phathom Item"

    @Parameter(title: "Item ID")
    var itemID: String

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .openPhathomItem,
            object: nil,
            userInfo: ["itemID": itemID]
        )
        return .result()
    }
}

extension Notification.Name {
    static let openPhathomItem = Notification.Name("openPhathomItem")
}
```

Handle the notification in `MainTabView` to switch to Library tab and push to the item's `DetailView`.

Register `NSUserActivity` handling in `PhathomApp` so Spotlight taps route through `OpenItemIntent`.

---

## Acceptance Criteria

Phase 2 is complete when:

- [ ] `mattt/llama.swift` (or chosen wrapper) is integrated as a Swift Package dependency
- [ ] Settings tab has a model picker that discovers `*.gguf` files and persists the selection
- [ ] Settings shows recommended model suggestions with download guidance
- [ ] A test inference button in Settings verifies the selected model works
- [ ] `BGAppRefreshTask` and `BGProcessingTask` are registered and schedulable
- [ ] A newly created `ContentItem` (via Add New tab) transitions through processing states automatically when the app enters background
- [ ] `summaryBullets`, `tags`, and `extracts` are populated by real Llama.cpp inference — not hardcoded
- [ ] The library UI reflects real-time status changes (processing badge appears/disappears as items are processed)
- [ ] `processingDetail` shows meaningful micro-state labels during processing
- [ ] The model is loaded at task start and unloaded at task end (no persistent memory hold)
- [ ] Thermal throttling pauses processing when the device is hot
- [ ] Completed items appear in Spotlight search with title, summary, and tags
- [ ] Tapping a Spotlight result opens the app directly to that item's detail screen
- [ ] State checkpointing works: killing the app mid-processing and relaunching resumes where it left off
- [ ] JSON parsing failures for LLM output degrade gracefully (partial data, not `.failed` status)
- [ ] The existing seed data and UI from Phase 1 still work correctly

---

## Out of Scope — Do NOT Build These

- Share sheet extension (could be added as a Phase 2.5 follow-up, but not core)
- RAG chat (Phase 3)
- Voice memo capture
- Any cloud or sync features
- Apple FoundationModels integration
- Translation feature (button exists in UI but stays as a stub)
- Support for non-Llama-3 prompt templates (document as a future enhancement)

---

## Open Questions — Agent Discretion

The implementing agent MAY decide:
- HTML parsing strategy for web scraping (basic regex, `SwiftSoup` if justified, or `WKWebView` snapshot)
- Whether to use `async let` parallelism within a single BG task or process items strictly sequentially
- Whether to use `mattt/llama.swift` (lower-level, C API) or `pgorzelany/swift-llama-cpp` (higher-level `LlamaService`)
- Exact `n_ctx` and `n_batch` values for the llama context (start with 4096/512)
- Whether the Spotlight `AppIntent` uses `NSUserActivity` continuation or a custom notification
- Layout and UX details of the model picker in Settings

The implementing agent MUST escalate / ask before:
- Adding any new SwiftData models (e.g., `TextChunk` for embeddings)
- Adding any third-party Swift packages beyond the llama.cpp wrapper
- Changing any existing SwiftData model properties from Phase 1
- Changing the processing state enum values
- Implementing support for non-Llama-3 chat templates (defer to future)
