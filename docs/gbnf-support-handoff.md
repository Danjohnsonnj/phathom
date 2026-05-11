<handoff>
GOAL: handoff after GBNF crash review (commit 27c90113) for next session to fix or mitigate `Unexpected empty grammar stack` on `{"` piece
ENV: Swift 6 / iOS | repo:phathom | branch:gbnf-support | cwd:/Users/danjohnson/Local Documents/repos/phathom | HEAD:27c9011
STATE: Phathom/Phathom/Inference/GBNFGrammars.swift | GenerationOptions.swift | LlamaContentAnalyzer.swift | LlamaCppBridge.swift | LlamaCppRuntime.swift | PhathomTests/GBNFGrammarsTests.swift | docs/decisions.md
DECISIONS:
  - crash @ LlamaCppRuntime.swift:391 -> `llama_sampler_sample` triggers C++ `llama_sampler_accept` on grammar; not Swift line bug
  - piece `{"` token ~5018 -> matches upstream llama.cpp grammar issues (e.g. #18173); framework version primary lever
  - `string` GBNF line matches upstream json.gbnf bytes -> unlikely Swift `#"""` mangling for `\x` there
  - sampler integration -> Phathom: grammar inside chain after temp; llama `common_sampler` applies grammar separate / grammar_first -> consider aligning if bump insufficient
DONE:
  - reviewed commit 27c90113 diff + LlamaCppRuntime.swift generate loop + GBNFGrammars.swift
  - traced `llama_sampler_sample` apply/accept + chain order vs common/sampling.cpp pattern
AVOID:
  - assuming bug at Swift:391 only -> exception from grammar accept in llama
  - rewriting GBNF first -> upstream + sampler order likely dominate
TODO:
  - plan at `~/.cursor/plans/gbnf-leak-fixes_fc88d597.plan.md`
  - rebuild/bump Phathom/vendor/llama/llama.xcframework from recent llama.cpp (grammar fixes)
  - if still crashes: split grammar from chain; apply grammar before top_k/top_p/temp like common_sampler
  - repro: note which task grammar (string array vs extract) + first sampled token vs expected `[` vs `{`
NEXT: rebuild xcframework from current llama.cpp master (or known good post-grammar-fix SHA), swap into vendor, rerun same analyze path on simulator
BLOCKED: none — confirm exact GGUF + which analyzer step fails if repro ambiguous
</handoff>
