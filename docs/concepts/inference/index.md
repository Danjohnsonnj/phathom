# Inference & pipeline concepts

Thin stubs — **links only**. Parent index: [`docs/concepts/index.md`](../index.md).

**Vendored engine:** `Phathom/vendor/llama/llama.xcframework` — pinned to llama.cpp **b11719**; build or copy: [`README.md`](../../../README.md) (XCFramework section). A19+ Metal 4 tensor acceleration is runtime-detected from the embedded kernels; simulator inference remains CPU-only.

| Term | Description |
|------|-------------|
| [withSession](./with-session.md) | Serialized GGUF access; no parallel Llama calls |
| [KV cache reuse](./kv-cache-reuse.md) | Article prefix decoded once; per-task seq fork |
| [BackgroundPipeline](./background-pipeline.md) | Scrape → embed → analyze orchestration |
| [SharedLlamaInference](./shared-llama-inference.md) | Single shared session; primary vs tagging GGUF |
| [GGUF bookmark](./gguf-bookmark.md) | Security-scoped model file reference |
| [PipelineUserPause](./pipeline-user-pause.md) | Global pause gates scheduling |
| [VisionContentAnalyzer](./vision-content-analyzer.md) | Media VLM via libmtmd |

**Recall-then-read:** agentmemory `memory_recall(inference)` → this index → Swift (when MCP available).
