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

## Agent Guardrails

**Read this section first. These rules are non-negotiable.**

### Source of truth hierarchy

1. **`docs/decisions.md`** — highest authority. Includes decisions from all prior phases.
2. **This hand-off document** — defines scope, deliverables, and acceptance criteria.
3. **Phase 2 hand-off** — describes **`LlamaContentAnalyzer` / `LlamaCppRuntime`**, the BG pipeline, and model lifecycle patterns you must reuse. Do not reinvent these.
4. **Phase 1 hand-off** — describes the original UI. Library and detail screens are not your concern unless this document explicitly says to modify them.

### Behavioral rules

- **Build, don't plan.** Produce working code. No mockup exists for the chat screen — the spec in this document is the design. Do not produce wireframes, design alternatives, or ask for approval on visual direction. Follow the spec, use standard iOS messaging patterns, and let the user refine after seeing it work.
- **Reuse Phase 2 patterns.** Use **`LlamaContentAnalyzer`** + **`LlamaCppRuntime`** for inference. Use the same JSON parsing and fallback patterns. Use the same prompt conventions (**Llama-3 Instruct** GGUFs via the model’s chat template). Do not add alternative LLM wrappers.
- **Do not break Phases 1 or 2.** Library, detail, filter pills, BG processing, Spotlight indexing, and model management must all continue to work. Do not refactor Phase 1-2 code unless this document explicitly requires a change.
- **Schema is frozen.** `ChatThread` and `ChatMessage` already exist from Phase 1. Use them as defined. Do not add properties without escalation. If RAG requires intermediate data structures (chunk caches, embedding buffers), use in-memory types — not new SwiftData models — unless you escalate first.
- **Model lifecycle differs from Phase 2.** In Phase 2, the model is loaded and unloaded within a single BG task. In Phase 3, the model should stay warm for the duration of a chat session (foreground use). Unload when the user leaves the chat thread or the app backgrounds. Document this clearly in your code.
- **Stay in your phase.** Do not build share sheet extensions, voice memo capture, export features, or any post-v1 items listed in the "Future Considerations" section. Those are context for decision-making, not scope.
- **Grounding over creativity.** The RAG system must answer from source content only. If the retrieved chunks don't contain enough information, the response should say so. Do not configure the LLM to improvise, speculate, or use general knowledge. Test this with a question that has no answer in the source data.
- **After completing work, update docs.** Append any new decisions to [docs/decisions.md](../decisions.md). Update the `What Exists After Phase 2` section in this document with what actually exists now.

### Decision framework — handling unknowns

You will encounter situations this spec does not explicitly cover. Use this ordered framework to decide what to do:

**Step 1: Is it a technical blocker?**
The spec says to do X but the Phase 2 **`LlamaContentAnalyzer`** / **`LlamaCppRuntime`** API doesn't support it, or an embedding/retrieval approach doesn't work as expected.
- **Action**: Adapt within the existing patterns. If the runtime needs a new method (e.g., streaming), extend **`LlamaCppRuntime`** / **`LlamaCppBridge`** rather than adding a parallel stack. If the embedding approach from Phase 2 doesn't give good retrieval results, adjust parameters (chunk size, top-K) before considering an architectural change.
- Note what you changed and why in a code comment.

**Step 2: Is it an ambiguity gap?**
The chat UI or RAG behavior has a scenario the spec doesn't address.
- **Action**: Apply the **standard messaging app convention** for UI questions and the **conservative retrieval** convention for RAG questions.
- Defaults to apply when the spec is silent:
  - Chat UI: follow Apple Messages / iMessage conventions for bubble layout, keyboard handling, scroll behavior, and empty states.
  - If retrieval returns zero relevant chunks: the assistant should say "I don't have enough information in your saved items to answer that. Try saving more content related to this topic." Do not fall back to the model's general knowledge.
  - If the model's response doesn't contain source citations: display it anyway — citations are ideal but not a reason to reject an otherwise grounded response.
  - If conversation starters fail to generate: use the hardcoded fallback array. Do not show an error.
  - Thread ordering: `createdAt` descending (newest first) in the thread list.
  - Message ordering: chronological (oldest first) within a thread.

**Step 3: Is it a product decision?**
Something could go multiple ways and changes the chat experience meaningfully.
- **Action**: **Stop and ask the user.** Frame it as two concrete options.
- Examples that require asking: whether to support multi-turn context (sending prior messages back to the LLM — the spec flags this explicitly), whether to add a "clear thread" or "delete thread" action, whether the tag picker should allow creating new tags or only select existing ones.

**Step 4: Is it a structural constraint?**
You need to change something in the guardrails' "must escalate" list.
- **Action**: **Full stop on that task.** Describe the problem, what you tried, and why the constraint is blocking you.

**General principle**: In Phase 3, **retrieval quality and grounding** trump polish. A chat that gives accurate, sourced answers with plain formatting is better than a chat with beautiful markdown rendering that sometimes hallucinates.

### Completion protocol

When you believe the work is done:
1. Verify every acceptance criteria checkbox can be checked.
2. Confirm the app builds without warnings or errors.
3. Confirm Phase 1 functionality (library, detail, filter, seed data) still works.
4. Confirm Phase 2 functionality (BG processing, Spotlight, model picker) still works.
5. Test a RAG query where the answer IS in the source data — verify grounded response.
6. Test a RAG query where the answer is NOT in the source data — verify the model declines rather than hallucinating.
7. Append any new decisions to [docs/decisions.md](../decisions.md).
8. State which acceptance criteria are met and which (if any) are not, with reasons.
9. List any decisions you made under Steps 1-2 of the decision framework so the user can review them.

---

## What Exists After Phase 2

Phase 2 (as implemented) adds:

- **Llama.cpp**: vendored **`Phathom/vendor/llama/llama.xcframework`**, first-party types in **`Phathom/Phathom/Inference/`** (`LlamaCppRuntime`, `LlamaContentAnalyzer`, `LlamaCppBridge`, `GenerationOptions`, `LlamaInferenceError`). Prompts use the GGUF’s **chat template** via **`startTemplatedUserPrompt`** (Llama-3 Instruct–compatible GGUFs expected).
- **Model management**: **`Services/ModelManager.swift`**, **`Views/Settings/SettingsTab.swift`** (pick / import / test / links).
- **Background work**: **`Services/BackgroundPipeline.swift`**, **`Services/WebIngestService.swift`**, **`Services/ThermalMonitor.swift`**. No **embedding vectors** stored yet — **`embedding`** is only a pipeline stage before Llama work.
- **Spotlight + deep links**: **`Models/ContentItem+Spotlight.swift`**, **`AppIntents/OpenPhathomItemIntent.swift`**, **`Helpers/Notifications+Phathom.swift`**, wired in **`MainTabView`** + **`LibraryTab`** (`NavigationStack` + `NavigationPath`).
- **Capture**: **`AddNewTab`** persists **`ContentItem`** (web → `pending`; note → `embedding` with `rawText`) and schedules background work.

Chat tab remains a **placeholder**. **`ChatThread`** / **`ChatMessage`** are still unused until Phase 3.

### Files to Create / Modify (Phase 3 starters)

Reuse **`LlamaContentAnalyzer`** / **`LlamaCppRuntime`** for chat generation; add RAG-specific types under **`Phathom/Phathom/Services/`** and **`Phathom/Phathom/Views/Chat/`** per the tree in the Scope section below.

---

## Scope and Deliverables

Phase 3 replaces the Chat tab placeholder with a complete RAG-powered conversational interface. Users select tags to define a context scope, then ask questions that are answered using only their saved content.

### Files to Create / Modify

Phase 3 work extends the existing **`Phathom/Phathom/`** tree (see Phase 2 hand-off for inference and pipeline locations).

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

Per **Phase 2**: embeddings were **not** persisted. Phase 3 must introduce an **escalation-approved** storage strategy (or run embedding in memory only with trade-offs documented) before implementing similarity search.

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

Use **`LlamaContentAnalyzer`** streaming path (extend **`LlamaCppBridge`** / **`LlamaCppRuntime`** if needed) consistent with Phase 2.

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
func generateStarters(for chunks: [TextChunk], llama: LlamaContentAnalyzer) async throws -> [String] {
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
- Implement streaming in **first-party** Swift on top of **`import llama`** (decode loop + `AsyncStream` / `yield` pattern — same class as **Intrai** `LlamaCppInferenceEngine`)

Use the exact streaming API and cancellation hooks established in Phase 2 (`LlamaCppBridge` / inference actor); Phase 3 only consumes that seam.

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
