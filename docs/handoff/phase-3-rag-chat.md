# Phase 3 Hand-off: RAG Chat + Conversational Discovery (Skeleton — Finalize After Phase 2)

> **Status**: This is a skeleton. Most implementation details depend on Phase 2 outcomes — specifically which AI engine was selected and how embeddings are stored. Sections marked `[TBD after Phase 2]` will be filled in after Phase 2 completes.

## Project Snapshot

**Phathom** is a local-only iOS personal brain app. Phase 1 built the UI shell (TabView, library, detail). Phase 2 added real background AI processing (scraping, summarization, tagging, extraction) and Spotlight integration. Phase 3 activates the Chat tab as a fully functional RAG-powered conversational interface.

- **Platform**: iOS 18+, Swift 5, SwiftUI, SwiftData
- **Storage**: Local-only — no CloudKit
- **AI engine**: **Llama.cpp** (sole engine — decided pre-Phase 2, see [docs/decisions.md](../decisions.md))

Read before starting:
- [docs/decisions.md](../decisions.md) — all prior decisions (including Phase 2 engine choice)
- [docs/handoff/phase-2-pipeline.md](phase-2-pipeline.md) — what Phase 2 built
- [docs/handoff/phase-1-ui-shell.md](phase-1-ui-shell.md) — original UI spec
- [docs/technical-brief.md](../technical-brief.md) — RAG pipeline architecture (section: "The RAG Pipeline for Phathom")

---

## What Exists After Phase 2

`[TBD after Phase 2 — update with actual file tree, embedding storage approach, AI engine integration patterns, and any schema changes]`

Expected state:
- Library and Detail screens fully functional with real AI-generated data
- BGTaskScheduler processing items through scrape → embed → summarize → tag → extract → completed
- Embeddings stored somewhere (SwiftData model, external file, or vector DB — depends on Phase 2 decision)
- Spotlight indexing for completed items
- Chat tab still shows placeholder from Phase 1
- `ChatThread` and `ChatMessage` SwiftData models exist but are unused

---

## Scope and Deliverables

Phase 3 replaces the Chat tab placeholder with a complete RAG-powered conversational interface. Users select tags to define a context scope, then ask questions that are answered using only their saved content.

### Files to Create / Modify

`[TBD after Phase 2 — exact paths depend on Phase 2 file structure]`

Expected new files:
```
Phathom/Phathom/
├── Views/Chat/
│   ├── ChatTab.swift              # Replace placeholder — thread list
│   ├── NewChatSheet.swift         # Tag selection to create a scoped thread
│   ├── ChatThreadView.swift       # Message list + input bar
│   ├── ChatMessageBubble.swift    # Single message row
│   └── ConversationStarters.swift # Auto-generated suggested questions
├── Services/
│   ├── RAGService.swift           # Retrieval + generation orchestration
│   ├── EmbeddingSearch.swift      # Vector similarity search
│   └── PromptBuilder.swift        # Constructs LLM prompts with retrieved chunks
```

---

## RAG Pipeline Architecture

This is the core of Phase 3. The flow:

```
User selects tags → fetch tagged ContentItems → chunk their rawText
→ embed the user's question → vector similarity search across chunks
→ top-K chunks injected into LLM prompt → LLM generates answer
→ stream tokens into ChatMessage → persist in ChatThread
```

### Step 1: Context Assembly

When the user creates a new chat thread, they select one or more tags. This defines the "scope."

```swift
// Fetch all content items matching the selected tags
let tagNames = selectedTags.map(\.name)
let descriptor = FetchDescriptor<ContentItem>(
    predicate: #Predicate<ContentItem> { item in
        item.processingStatus == "completed" && !item.isArchived
    }
)
let allItems = try context.fetch(descriptor)
let scopedItems = allItems.filter { item in
    item.tags.contains(where: { tagNames.contains($0.name) })
}
```

### Step 2: Chunking

Split each item's `rawText` into overlapping chunks for retrieval. Standard approach: 400-character chunks with 50-character overlap.

```swift
struct TextChunk {
    let itemID: UUID
    let index: Int
    let text: String
}

func chunkText(_ text: String, chunkSize: Int = 400, overlap: Int = 50) -> [String] {
    var chunks: [String] = []
    var start = text.startIndex
    while start < text.endIndex {
        let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
        chunks.append(String(text[start..<end]))
        let nextStart = text.index(start, offsetBy: chunkSize - overlap, limitedBy: text.endIndex) ?? text.endIndex
        start = nextStart
    }
    return chunks
}
```

### Step 3: Retrieval via Embedding Similarity

`[TBD after Phase 2 — depends on how embeddings are stored]`

Conceptual approach using Apple's NLEmbedding:

```swift
import NaturalLanguage

func findRelevantChunks(query: String, chunks: [TextChunk], topK: Int = 7) -> [TextChunk] {
    guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return [] }

    // Embed the query
    // NLEmbedding works at the word level; for sentence-level,
    // use NLEmbedding.sentenceEmbedding(for:) if available,
    // or a custom embedding approach from Phase 2

    // [TBD — Phase 2 will have established the embedding approach.
    //  This section should use the same embedding method for consistency.]

    // Score each chunk by cosine similarity and return top K
    let scored = chunks.map { chunk -> (TextChunk, Double) in
        let distance = computeSimilarity(query, chunk.text)
        return (chunk, distance)
    }
    .sorted { $0.1 > $1.1 }

    return Array(scored.prefix(topK).map(\.0))
}
```

### Step 4: Prompt Construction

Build a prompt that grounds the LLM in the retrieved chunks:

```swift
func buildRAGPrompt(question: String, chunks: [TextChunk]) -> String {
    let context = chunks.enumerated().map { i, chunk in
        "[Source \(i + 1)]: \(chunk.text)"
    }.joined(separator: "\n\n")

    return """
    You are a research assistant. Answer the user's question using ONLY the provided sources. \
    If the sources don't contain enough information, say so. Cite source numbers when possible.

    ## Sources
    \(context)

    ## Question
    \(question)

    ## Answer
    """
}
```

### Step 5: Generation (Llama.cpp)

`[TBD after Phase 2 — use the same LlamaService and model lifecycle pattern established in Phase 2]`

Key differences from Phase 2's BG inference:
- **Keep the model warm** during a chat session (user is actively waiting — don't load/unload per message)
- **Stream tokens** as they're generated — each partial token appends to `ChatMessage.text` for live UI updates
- **Context window**: set `n_ctx` large enough for the RAG prompt + response (8192+ recommended for chat)
- **Prompt format**: use the same Llama-3 chat template from Phase 2, with the RAG prompt as the user message

### Step 6: Persistence

```swift
let userMessage = ChatMessage(role: "user", text: question)
let assistantMessage = ChatMessage(role: "assistant", text: response)
thread.messages.append(contentsOf: [userMessage, assistantMessage])
try context.save()
```

---

## Tricky Part: Conversation Starters

When a user opens a new (empty) chat thread, show 3 auto-generated suggested questions above the input bar. This eliminates blank-page anxiety (see: NotebookLM, Perplexity).

### Approach

After the context is assembled (Step 1-2), run a quick generation using Llama.cpp:

```swift
func generateStarters(for chunks: [TextChunk], llama: LlamaService) async throws -> [String] {
    let sample = chunks.prefix(10).map(\.text).joined(separator: "\n")
    let prompt = """
    Based on these saved items, suggest exactly 3 interesting questions a user might ask. \
    Output ONLY a JSON array of 3 strings, no other text.

    \(sample)
    """
    let output = try await llama.generate(prompt: prompt)
    // Parse JSON array from output, same strip-and-decode pattern as Phase 2
    return parseJSONStringArray(output) ?? [
        "What are the common themes across these items?",
        "Summarize the key takeaways.",
        "What connections exist between these topics?"
    ]
}
```

The fallback array ensures the UI always has starters even if generation fails.

Display as tappable pills above the text input. Tapping one submits it as the first user message.

---

## Chat UI Design

> No mockup exists for the chat screen. This is a design spec to be refined.

### Chat Tab — Thread List

- Navigation title: "Deep Dive"
- List of existing `ChatThread` records, sorted by `createdAt` descending
- Each row: thread `topic`, tag pills, last message preview, timestamp
- "New Chat" button in toolbar → presents `NewChatSheet`
- Empty state: illustration + "Select topics to start a conversation with your saved content"

### New Chat Sheet

- Multi-select tag picker (all tags from the user's library)
- Shows count of items matching selected tags
- "Start Chat" button → creates `ChatThread` with `sourceTags`, pushes to `ChatThreadView`

### Chat Thread View

- Standard chat bubble layout: user messages right-aligned, assistant messages left-aligned
- Assistant messages support basic markdown rendering (bold, bullets, numbered lists)
- Conversation starters shown above input bar for new/empty threads
- Input bar: text field + send button, fixed to bottom with keyboard avoidance
- Source citations: when the assistant references "[Source 2]", make it tappable → navigates to that `ContentItem`'s detail view

### Streaming UX

Llama.cpp supports token-by-token streaming natively. Use this for chat responses:

- Show a typing indicator while the model processes the prompt
- As each token is generated, append it to `ChatMessage.text` — SwiftUI will re-render progressively
- The `pgorzelany/swift-llama-cpp` wrapper provides `AsyncSequence`-based streaming; if using `mattt/llama.swift` directly, implement a callback-based token loop

`[TBD after Phase 2 — use the exact streaming pattern established by the LlamaService wrapper chosen in Phase 2]`

---

## Acceptance Criteria

Phase 3 is complete when:

- [ ] The Chat tab shows a list of existing chat threads (or an empty state)
- [ ] Users can create a new chat by selecting tags
- [ ] The tag picker shows all tags from the library with item counts
- [ ] A new chat displays 3 auto-generated conversation starters
- [ ] Tapping a starter submits it as the first message
- [ ] User questions are answered using RAG — responses reference actual saved content
- [ ] Responses are grounded: the LLM does not hallucinate facts that aren't in the source content
- [ ] Chat messages persist in SwiftData and survive app restart
- [ ] Chat threads can be resumed (opening an existing thread shows full history)
- [ ] Source citations in responses are tappable and navigate to the source item's detail view
- [ ] The existing Library, Detail, and BG processing from Phases 1-2 continue to work
- [ ] Performance: response generation completes within ~10 seconds for a typical question

---

## Out of Scope — Do NOT Build These

- Share sheet extension
- Voice memo capture or transcription
- Multi-turn agentic workflows (the LLM answers questions, it doesn't take actions)
- Export or sharing of chat transcripts
- Any cloud features

---

## Open Questions — Agent Discretion

The implementing agent MAY decide:
- Exact chunk size and overlap parameters (400/50 is a starting point; tune based on retrieval quality)
- Chat bubble visual design (standard messaging patterns are fine)
- Whether to cache assembled chunks in memory for the duration of a chat session
- Markdown rendering approach for assistant messages (`AttributedString` vs a lightweight library)
- Animation for conversation starters appearing

The implementing agent MUST escalate / ask before:
- Changing the embedding or vector storage approach established in Phase 2
- Adding any new SwiftData models
- Adding third-party packages (especially LLM-related)
- Modifying existing model schemas
- Implementing multi-turn context (sending prior messages back to the LLM) — this affects prompt size and may not fit in context window

---

## Future Considerations (Post-Phase 3)

These are NOT in scope but inform decisions:
- **Smart shelves / grouped library rows**: AI-clustered topic groups on the library screen
- **Voice memo capture**: record → transcribe → process like any other content
- **Share sheet extension**: the original "Silent Capture" from the product brief
- **Cross-item synthesis**: "Compare all articles tagged 'architecture'" as a first-class action from the library, not just chat
- **Export**: share chat transcripts or summaries as formatted documents
