# Product Brief: Phathom

Objective:
A private, local-first iOS "Personal Brain" that captures digital content (links, photos, notes) and uses on-device LLMs to synthesize information through a conversational discovery interface.

## 1. Core Workflow

- The Silent Capture: A system share-sheet extension that accepts URLs, text, and images. It saves content immediately to a local database and dismisses, requiring zero user interaction at the moment of capture.
- The Background Processor: An asynchronous engine that manages the heavy lifting. It scrapes web content, performs OCR/Vision analysis on images, and generates summaries using a local Llama.cpp backend.
- The Deep Dive: A conversational UI where users select specific tags or "topics" to define a context window, allowing for targeted AI interrogation and synthesis of saved materials.

## 2. Key Features## A. Intelligent Capture & Media Understanding

- Universal Share Support: Handles articles, social posts, photos, and voice memos.
- Multimodal Vision: Beyond simple OCR, the app uses on-device vision models to understand image context (e.g., recognizing a "modernist floor plan" vs. a "grocery receipt").
- Resilient Processing: A state-aware queue that checkpoints AI tasks. If iOS terminates the background process, Phathom resumes exactly where it left off (e.g., mid-summary) once resources are available.

## B. "Topic-First" Organization

- Collapsed Taxonomy: Tags and Collections are merged into a single concept. A "Collection" is simply a dynamic filter of one or more tags.
- AI Auto-Tagging: The LLM suggests and applies tags based on content analysis to maintain an organized library without manual effort.

## C. Conversational Discovery (RAG)

- Contextual Chat: Users "deep dive" into topics by selecting tags. The AI uses Retrieval-Augmented Generation (RAG) to pull facts from only those tagged items.
- Synthesis & Reasoning: Users can ask complex questions like, "Compare the three investment articles I saved this morning," or "Draft a summary of my 'Home Renovation' tags."

## 3. Technical Strategy

- Platform: iOS 16.4+ (Optimized for iPhone 16 Pro hardware).
- Privacy: Local-only storage (SwiftData). No cloud processing; no third-party tracking.
- AI Engine: Llama.cpp for LLM/VLM tasks, utilizing the Apple Neural Engine (ANE) via Metal.
- Search/Indexing: Apple Natural Language Framework for fast initial semantic vector search, feeding results into the LLM for final synthesis.

## 4. Design Principles

- Status Transparency: Clear UI indicators for "Processing," "Analyzed," and "Pending" states to manage expectations around local LLM speed.
- Resource Awareness: AI tasks are throttled based on thermal state and battery level, prioritizing execution during charging cycles.
- Utility over Friction: The app stays out of the way during "Capture" and provides a focused, chat-centric experience during "Review."

## 5. Archive & recovery (soft delete)

**Archive** removes an item from the library immediately (same mental model as delete), with a short on-screen **Undo** and a **Recently Deleted** area under Settings. The app retains the underlying record for **48 hours** from archive time, then **permanently deletes** it. Conversational discovery and the main library **exclude** archived content. Detail: [decisions.md](decisions.md) and [handoff/phase-1-ui-shell.md](handoff/phase-1-ui-shell.md).
