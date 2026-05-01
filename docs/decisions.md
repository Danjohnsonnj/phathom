# Phathom — Decision Log

Running record of architectural and product decisions. Every phase appends here. When starting a new phase, read this entire file before beginning work.

| Date | Decision | Rationale | Phase |
|------|----------|-----------|-------|
| 2026-05-01 | App name is **Phathom** | Mockups used "LinkSavr" as a placeholder; repo name is canonical | Pre |
| 2026-05-01 | **Local-only forever** — no CloudKit, no sync | Simplifies schema (no conflict resolution, no blob size limits), aligns with privacy-first brief | Pre |
| 2026-05-01 | AI engine **TBD** — evaluate Apple FoundationModels vs Llama.cpp in Phase 2 | Both have trade-offs (bundle size vs device requirement); need on-device benchmarks before committing | Pre |
| 2026-05-01 | Delivery is **3 phases**: UI shell → pipeline → RAG chat | De-risks by proving UI/data model before investing in AI integration | Pre |
| 2026-05-01 | **Remove FAB** from library screen; Add New tab is the sole capture entry point | Mockup showed both FAB and tab, which is redundant; one path reduces confusion | Pre |
| 2026-05-01 | `summaryBullets` and `extracts` stored as **JSON strings** on ContentItem, not as separate model relationships | SwiftData relationships for variable-length structured data add complexity with no query benefit; Codable helpers keep it clean | Pre |
| 2026-05-01 | "Key Figures" generalized to **Extracts** — label/value pairs applicable to any content type | Mockup's "Extracted Key Figures" is too narrow; recipes have ingredients, articles have names/dates, photos have descriptions | Pre |
| 2026-05-01 | `processingStatus` uses **granular sub-states** (pending/scraping/embedding/summarizing/tagging/completed/failed) | Enables micro-state labels in the library UI per the "Status Transparency" design principle | Pre |
| 2026-05-01 | **Spotlight + AppIntent** integration added to Phase 2 scope | High-value, low-effort; makes the "personal brain" searchable system-wide | Pre |
| 2026-05-01 | Thumbnail fallback uses **deterministic color from UUID** + content-kind icon | Ensures consistent visual rhythm in library rows even when no image exists | Pre |
| 2026-05-01 | **Llama.cpp is the sole AI engine** — no Apple FoundationModels | Direct experience: FM crashed after a few chat exchanges (4096 token context limit, uncaught error). FM is still beta-unstable (EXC_BAD_ACCESS, dyld errors, guardrail false positives, `@Generable` refusal regressions). FM's ~3B model is weaker than available 8B GGUF options. FM requires iPhone 15 Pro+ so a fallback would be needed anyway. Llama.cpp has been crash-free under extended use. | Pre |
| 2026-05-01 | **User-provided models** — no bundled GGUF files | User downloads recommended models and places them in the app's Documents directory. Selectable in Settings at any time. Eliminates ~4.5 GB bundle size. Allows experimentation with new models. | Pre |
| 2026-05-01 | **Llama-3 chat template only** for v1 prompt format | Support one template well rather than many poorly. Non-Llama-3 models may still work but prompt format is not guaranteed. Document as a future enhancement. | Pre |
| 2026-05-01 | **Graceful JSON parse failure** — partial data, not `.failed` status | If LLM output can't be parsed as JSON for summaryBullets/tags/extracts, set the field to nil but still mark item `.completed`. Better to have an item with a title and no summary than one stuck in `.failed`. | Pre |
| 2026-05-01 | **BGProcessingTask `requiresExternalPower` = false** for analyze | Phase 2 hand-off suggested `true`; **false** lets analysis progress on battery during development and typical mobile use. Revisit if iOS jetsam or thermal issues appear in production. | 2 |
| 2026-05-01 | **No embedding persistence in Phase 2** | `embedding` is a pipeline state only; vector storage requires escalation (new model or external store). RAG/chunking deferred to Phase 3. | 2 |
