# 1. SwiftData Schema: The Data Model

We need a structure that links raw content to AI-generated metadata while maintaining a robust "Processing State" to handle background interruptions.

```swift
import Foundationimport SwiftData
@Modelfinal class ContentItem {
    // 1. Basic Metadata
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String?
    var originalURL: URL?

    // 2. Polymorphic Content
    var rawText: String?          // Scraped web text or note
    var imageBlob: Data?          // Local storage for photos
    var mediaDescription: String? // AI-generated context of the image

    // 3. AI Metadata & Organization
    var summary: String?
    @Relationship(deleteRule: .nullify) var tags: [Tag] = []

    // 4. Processing State Machine
    // States: .pending, .processing, .completed, .failed
    var processingStatus: String = "pending"
    var lastProcessedChunk: Int = 0 // For resuming interrupted tasks
    var failureReason: String?

    init(id: UUID = UUID(), createdAt: Date = Date(), originalURL: URL? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.originalURL = originalURL
    }
}
@Modelfinal class Tag {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \ContentItem.tags) var items: [ContentItem] = []

    init(name: String) {
        self.name = name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
@Modelfinal class ChatThread {
    var id: UUID
    var topic: String
    var createdAt: Date
    @Relationship var messages: [ChatMessage] = []
    @Relationship var sourceTags: [Tag] = [] // The "Context Filter"

    init(topic: String, sourceTags: [Tag] = []) {
        self.id = UUID()
        self.topic = topic
        self.createdAt = Date()
        self.sourceTags = sourceTags
    }
}
@Modelfinal class ChatMessage {
    var role: String // "user" or "assistant"
    var text: String
    var timestamp: Date

    init(role: String, text: String) {
        self.role = role
        self.text = text
        self.timestamp = Date()
    }
}
```

## Implementation Notes for the Schema

- The State Machine: By using processingStatus and lastProcessedChunk, the app can query ContentItem objects that are "pending" or "processing" as soon as it wakes up in the background.
- The Chat Context: The ChatThread stores a relationship to sourceTags. When you open a chat, we fetch all ContentItems associated with those tags to build the RAG context.
- Image Storage: For a "sole user" app, storing imageBlob in SwiftData is fine, but as your library grows, we might move this to an external directory with just a filePath in the model for performance.

## The RAG Pipeline for Phathom

The RAG (Retrieval-Augmented Generation) architecture is what transforms Phathom from a basic storage app into an intelligent research partner. By grounding the LLM's responses in your specific saved data, it provides accurate, context-aware insights while staying entirely offline.

The process follows a "Retrieval then Generation" flow:

1.  Ingestion & Chunking: When you save an article or image, the app's background worker scrapes the raw text or extracts a visual description. This content is broken down into smaller, manageable "chunks" (e.g., 300–500 characters).
2.  Embedding Creation: Each chunk is converted into a numerical vector—an embedding—using a model like Apple's NLEmbedding. These vectors represent the semantic meaning of the text, allowing for similarity-based searching later.
3.  Vector Storage: These embeddings are stored in an on-device vector database. For Phathom, we can use native options like ObjectBox or a lightweight Swift-based library like VecturaKit to ensure high-speed retrieval without external dependencies.
4.  Retrieval: When you ask a question in a "Deep Dive" chat, your query is also embedded. The system then calculates the "distance" between your query vector and the stored chunk vectors to find the top 5–10 most relevant matches.
5.  Augmented Generation: These relevant chunks are injected into a prompt for Llama.cpp, which then synthesizes an answer based only on those provided facts.

### Optimizing for iPhone 16 Pro

| Component        | Technical Selection    | Why?                                                                              |
| ---------------- | ---------------------- | --------------------------------------------------------------------------------- |
| Embedding Engine | NLEmbedding (Apple)    | Zero-RAM overhead; runs on the Neural Engine.                                     |
| Vector Search    | ObjectBox Swift        | Built specifically for on-device RAG; highly performant for thousands of items.   |
| Generator        | Llama.cpp (Llama-3-8B) | 4-bit quantization fits comfortably in the Pro's RAM for fast, private reasoning. |

## Technical Design: Background Processing & Task Orchestration

### 1. The "Deferred Intelligence" Model

To maintain the "Silent Save" promise, Phathom uses a Capture-First, Process-Later architecture.

- Share Extension: Only performs the initial database write (SwiftData). It does not trigger AI.
- The Coordinator: A dedicated service that watches for pending items and manages the queue based on system telemetry (battery, thermals).

### 2. Implementation Strategy: BGTaskScheduler

We will register two distinct types of background tasks to handle the workload:

#### A. The "Short-Burst" Task (BGAppRefreshTask)

- Trigger: Scheduled frequently by iOS (every few hours).
- Goal: Perform lightweight tasks like web scraping and generating Apple NL Embeddings.
- Duration: ~30 seconds.
- Execution: Scrapes 2-3 new links and prepares them for the heavier LLM processing.

#### B. The "Deep-Processing" Task (BGProcessingTask)

- Trigger: Scheduled for when the phone is charging and ideally on Wi-Fi (e.g., overnight).
- Goal: Run Llama.cpp for summarization, auto-tagging, and multimodal vision analysis.
- Resource Access: Requires requiresExternalPower = true and requiresNetworkConnectivity = false.
- Duration: Can run for minutes if the system allows.

### 3. State Checkpointing (The "Resume" Logic)

Since iOS can kill a background task with only a few seconds' notice, we implement a State Machine in SwiftData:

- Atomic Chunks: Large articles are split into smaller chunks.
- Progress Persistence: After the LLM summarizes a chunk, the lastProcessedChunk index is immediately saved to disk.
- The "Expiration" Handler: We use the expirationHandler block provided by iOS to gracefully pause the Llama.cpp inference engine and save the current state before the process is killed.

### 4. Thermal & Power Management

On an iPhone 16 Pro, the Neural Engine is powerful but can generate heat.

- Thermal Monitoring: The app will subscribe to ProcessInfo.thermalStateDidChangeNotification.
- Throttling: If the state hits .fair or .serious, all background AI processing is paused immediately to prevent device slowdown or battery degradation.

### 5. Summary of Background Workflow

| Phase   | Task Type       | Trigger        | Action                            |
| ------- | --------------- | -------------- | --------------------------------- |
| Capture | Share Extension | User Action    | Save URL/Image to SwiftData.      |
| Ingest  | BGAppRefresh    | System-driven  | Scrape text, create Embeddings.   |
| Analyze | BGProcessing    | Charging/Night | Llama.cpp Summarization & Vision. |
| Cleanup | Foreground      | App Launch     | Finalize tags and refresh the UI. |
