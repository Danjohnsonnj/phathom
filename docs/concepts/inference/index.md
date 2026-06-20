# Inference & pipeline concepts

Thin stubs — **links only**. Full glossary table: [`CONTEXT.md`](../../../CONTEXT.md#inference--pipeline).

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

Parent index: [`docs/concepts/index.md`](../index.md)
