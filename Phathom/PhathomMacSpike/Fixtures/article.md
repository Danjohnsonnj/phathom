# Spike Title

Paragraph with **bold** word and [link](https://example.com) text.

- Alpha item
- Beta item

> Quoted words

Inline `tick` code.

The quick brown fox jumps over the lazy dog while researchers debate whether on-device language models can summarize long-form articles without leaking private reading habits to the cloud. Local inference keeps the full article body on the machine, which matters when the source material includes medical notes, financial filings, or journal entries that should never leave the device.

Engineers tuning llama.cpp on Apple Silicon typically watch peak resident memory during prefill-heavy workloads because article summarization spends most of its time processing thousands of input tokens before generating a short JSON response. Metal acceleration moves matrix multiplications off the CPU, but unified memory still means the operating system can reclaim pages when multiple apps compete for RAM.

Phathom's analyze pipeline prefills the article once, then reuses the KV cache prefix for summary and extract tasks so the model does not re-read the entire document for every structured output. That design trades implementation complexity for lower latency and better battery life on phones, and it should behave similarly on macOS once the same runtime ships on desktop hardware with more headroom.
