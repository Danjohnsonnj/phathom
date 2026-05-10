import PhathomCore
import Foundation
import Darwin

#if canImport(llama)
import llama

nonisolated final class LlamaCppRuntime: @unchecked Sendable, LlamaCppBridge {
    struct RuntimeConfig: Sendable {
        /// Requested `n_ctx` before capping to `llama_model_n_ctx_train`. KV-cache RAM scales ~linearly with this value;
        /// Phathom unloads between `withSession` runs. On **8GB** unified-memory phones (e.g. iPhone 16 Pro), **8192** is a
        /// practical default for typical **7–8B Q4** GGUFs—if you see Jetsam/OOM, try a smaller quant or lower this value
        /// (`LlamaContentAnalyzer` token fitting still avoids oversize *prompts*).
        let contextWindow: UInt32
        let promptSlackTokens: Int
        /// Physical kernel-level batch size (`n_ubatch`). 1024 is chosen over the llama.cpp standard 512 because
        /// Phathom's pipeline is heavily prefill-dominated (3–8k token articles). Must be ≤ `contextWindow`; since
        /// `n_batch` is set to the full context window, this constraint is always satisfied. Lower to 512 if OOM on
        /// very small quants or older devices.
        let physicalBatchSize: UInt32

        static let `default` = RuntimeConfig(contextWindow: 8192, promptSlackTokens: 64, physicalBatchSize: 1024)

        init(contextWindow: UInt32, promptSlackTokens: Int, physicalBatchSize: UInt32 = 1024) {
            self.contextWindow = contextWindow
            self.promptSlackTokens = promptSlackTokens
            self.physicalBatchSize = physicalBatchSize
        }
    }

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var shouldCancel = false
    private let config: RuntimeConfig
    private var contextLimitTokens: Int = Int(RuntimeConfig.default.contextWindow)

    private var generationSampler: UnsafeMutablePointer<llama_sampler>?
    private var promptTokenBuffer: UnsafeMutablePointer<llama_token>?
    private var decSingleToken: UnsafeMutablePointer<llama_token>?

    private var nPos: Int = 0
    private var nPrompt: Int = 0
    private var nPredict: Int = 0
    private var lastSampledToken: llama_token = 0
    private var hasActiveGeneration: Bool = false

    private static let abortTrampoline: @convention(c) (UnsafeMutableRawPointer?) -> Bool = { data in
        guard let data else { return false }
        let runtime = Unmanaged<LlamaCppRuntime>.fromOpaque(data).takeUnretainedValue()
        return runtime.shouldCancel
    }

    init(config: RuntimeConfig = .default) {
        self.config = config
        self.contextLimitTokens = Int(config.contextWindow)
    }

    deinit {
        releaseGenerationState(freeContext: true)
        llama_backend_free()
    }

    func loadModel(path: String) throws {
        releaseGenerationState(freeContext: true)
        shouldCancel = false

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            throw LlamaInferenceError.modelLoadFailed("Model file not found on disk.")
        }
        guard fileManager.isReadableFile(atPath: path) else {
            throw LlamaInferenceError.modelLoadFailed("Model file is not readable.")
        }
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let size = attributes[.size] as? UInt64 ?? 0
        guard size > 0 else {
            throw LlamaInferenceError.modelLoadFailed("Model file is empty.")
        }

        llama_backend_init()

        var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
#else
        modelParams.n_gpu_layers = -1
#endif

        guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
            throw LlamaInferenceError.modelLoadFailed(
                "llama.cpp could not load the model. The file may be corrupt or unsupported."
            )
        }

        var contextParams = llama_context_default_params()
        let trainCtx = Int(llama_model_n_ctx_train(loadedModel))
        let requested = config.contextWindow
        let effectiveCtx: UInt32
        if trainCtx > 0 {
            effectiveCtx = min(requested, UInt32(clamping: trainCtx))
        } else {
            effectiveCtx = requested
        }
        contextParams.n_ctx = effectiveCtx
        // Logical batch: must be >= largest single llama_decode submission (full prompt on first pass).
        // n_batch=512 caused SIGABRT when nPrompt>512 (llama_decode rejects oversized batches).
        contextParams.n_batch = effectiveCtx
        // Physical (kernel-level) batch. 1024 is better than the llama.cpp default for prefill-heavy
        // pipelines (long articles); must be <= n_batch, which is always satisfied here.
        contextParams.n_ubatch = config.physicalBatchSize
        // Support up to 4 concurrent sequences: seq 0 (shared prefix) + task forks.
        contextParams.n_seq_max = 4
        // Flash Attention: AUTO lets llama.cpp enable it when both model and backend support it (Metal does
        // for Llama-3). Using AUTO rather than ENABLED so non-Llama-3 GGUFs degrade gracefully.
        contextParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO
        // Offload KQV ops (not just storage) to the GPU. Eliminates CPU↔GPU round-trips for the attention
        // pipeline. No-op when n_gpu_layers=0 (simulator); always safe to enable.
        contextParams.offload_kqv = true
        // Unified KV buffer is optimal when sequences share a large prefix (our shared-article-prefix case).
        contextParams.kv_unified = true

        let nThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        contextParams.n_threads = Int32(nThreads)
        contextParams.n_threads_batch = Int32(nThreads)

        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            throw LlamaInferenceError.modelLoadFailed("Unable to initialize llama context.")
        }

        model = loadedModel
        context = loadedContext
        contextLimitTokens = Int(contextParams.n_ctx)
    }

    func unloadModel() {
        releaseGenerationState(freeContext: true)
    }

    func countTemplatedUserPromptTokens(_ user: String) throws -> Int {
        guard let mdl = model else { throw LlamaInferenceError.modelNotLoaded }
        let formatted = makeFormattedChatPrompt(userText: user, model: mdl)
        let vocab = llama_model_get_vocab(mdl)
        let nTok = formatted.withCString { cstr in
            Int32(-llama_tokenize(vocab, cstr, Int32(strlen(cstr)), nil, 0, false, true))
        }
        guard nTok > 0 else {
            throw LlamaInferenceError.generationFailed("Failed to tokenize the prompt.")
        }
        return Int(nTok)
    }

    func maxTemplatedPromptTokensForGeneration(_ generationMaxTokens: Int) -> Int {
        let L = contextLimitTokens
        let S = config.promptSlackTokens
        // Clamp G to at least 1 so callers passing 0 get a conservative bound; all current call sites use >0.
        let G = max(1, generationMaxTokens)
        return max(1, min(L - S, L - G - 1))
    }

    func startTemplatedUserPrompt(_ user: String, options: GenerationOptions) throws {
        guard let mdl = model else { throw LlamaInferenceError.modelNotLoaded }
        let formatted = makeFormattedChatPrompt(userText: user, model: mdl)
        try startTokenizingPrompt(formatted, options: options)
    }

    func startRawPrompt(_ fullChatPrompt: String, options: GenerationOptions) throws {
        guard model != nil else { throw LlamaInferenceError.modelNotLoaded }
        try startTokenizingPrompt(fullChatPrompt, options: options)
    }

    func nextTokenChunk() throws -> String? {
        guard let ctx = context, let mdl = model, let smpl = generationSampler, let pBuf = promptTokenBuffer, let sBuf = decSingleToken else {
            if model != nil, context != nil, !hasActiveGeneration { return nil }
            throw LlamaInferenceError.modelNotLoaded
        }
        if shouldCancel {
            releaseGenerationState(freeContext: false)
            return nil
        }
        guard hasActiveGeneration else { return nil }

        let vocab = llama_model_get_vocab(mdl)

        let batch: llama_batch
        if nPos == 0 {
            batch = llama_batch_get_one(pBuf, Int32(nPrompt))
        } else {
            sBuf.pointee = lastSampledToken
            batch = llama_batch_get_one(sBuf, 1)
        }

        let batchLen = Int(batch.n_tokens)
        if nPos + batchLen >= nPrompt + nPredict {
            releaseGenerationState(freeContext: false)
            return nil
        }

        let dret = llama_decode(ctx, batch)
        if dret < 0 {
            releaseGenerationState(freeContext: false)
            throw LlamaInferenceError.generationFailed("Inference error during decode (code \(dret)).")
        }
        if dret == 1 {
            releaseGenerationState(freeContext: false)
            throw LlamaInferenceError.contextLimitReached("Context full — try shorter content.")
        }
        nPos += batchLen

        let newId = llama_sampler_sample(smpl, ctx, -1)
        if llama_vocab_is_eog(vocab, newId) {
            releaseGenerationState(freeContext: false)
            return nil
        }

        var piece = [CChar](repeating: 0, count: 512)
        var n = llama_token_to_piece(vocab, newId, &piece, Int32(piece.count), 0, true)
        if n < 0 {
            let need = -Int(n)
            piece = [CChar](repeating: 0, count: need + 1)
            n = llama_token_to_piece(vocab, newId, &piece, Int32(piece.count), 0, true)
        }
        lastSampledToken = newId

        guard n > 0 else { return "" }
        let clen = min(Int(n), piece.count)
        if clen < piece.count {
            piece[clen] = 0
        } else {
            piece[clen - 1] = 0
        }
        return String(cString: piece)
    }

    func cancelGeneration() {
        shouldCancel = true
    }

    func generateWithSharedPrefix(
        prefix: String,
        tasks: [SharedPrefixTask],
        onPartial: (String) -> Void
    ) throws {
        guard let ctx = context, let mdl = model else { throw LlamaInferenceError.modelNotLoaded }
        guard !tasks.isEmpty else { return }

        let vocab = llama_model_get_vocab(mdl)
        let mem = llama_get_memory(ctx)

        // ── 1. Tokenise all full prompts and find the shared token prefix length ──
        // Each full prompt = chat-template(prefix + taskSuffix). They share an identical opening
        // token run (the article body). We find the length by scanning for the first divergence.
        var taskTokens: [[llama_token]] = []
        taskTokens.reserveCapacity(tasks.count)

        for task in tasks {
            let formatted = makeFormattedChatPrompt(userText: prefix + task.suffix, model: mdl)
            let nTok = formatted.withCString { cstr in
                Int32(-llama_tokenize(vocab, cstr, Int32(strlen(cstr)), nil, 0, false, true))
            }
            guard nTok > 0 else {
                throw LlamaInferenceError.generationFailed("Failed to count tokens for task prompt.")
            }
            let buf = UnsafeMutablePointer<llama_token>.allocate(capacity: Int(nTok))
            defer { buf.deallocate() }
            let written = formatted.withCString { cstr in
                llama_tokenize(vocab, cstr, Int32(strlen(cstr)), buf, nTok, false, true)
            }
            guard written >= 0 else {
                throw LlamaInferenceError.generationFailed("Tokenisation failed for task prompt.")
            }
            taskTokens.append(Array(UnsafeBufferPointer(start: buf, count: Int(written))))
        }

        let minLen = taskTokens.map(\.count).min() ?? 0
        var commonLen = 0
        outer: for i in 0..<minLen {
            let ref = taskTokens[0][i]
            for arr in taskTokens.dropFirst() where arr[i] != ref { break outer }
            commonLen = i + 1
        }
        guard commonLen > 0 else {
            throw LlamaInferenceError.generationFailed("No common token prefix found across tasks.")
        }

        // ── 2. Context budget check ──
        let maxTailLen = taskTokens.map { $0.count - commonLen }.max() ?? 0
        let maxGen = tasks.map(\.maxTokens).max() ?? 0
        guard commonLen + maxTailLen + maxGen + config.promptSlackTokens <= contextLimitTokens else {
            throw LlamaInferenceError.contextLimitReached(
                "Prefix + longest task suffix + generation exceeds context window."
            )
        }

        // ── 3. Allocate a reusable batch sized for the largest single decode ──
        // Capacity covers prefix decode, per-task suffix decode, and single-token generation steps.
        let batchCap = Int32(max(commonLen, maxTailLen, 1))
        var batch = llama_batch_init(batchCap, 0, 1)
        defer { llama_batch_free(batch) }

        // ── 4. Decode shared prefix into seq 0 ──
        llama_memory_clear(mem, true)
        shouldCancel = false

        batch.n_tokens = Int32(commonLen)
        for i in 0..<commonLen {
            batch.token[i]   = taskTokens[0][i]
            batch.pos[i]     = Int32(i)
            batch.n_seq_id[i] = 1
            if let sid = batch.seq_id[i] { sid[0] = 0 }
            batch.logits[i]  = 0
        }
        batch.logits[commonLen - 1] = 1  // logits for last prefix token (needed by first task's sampler)

        let prefixRet = llama_decode(ctx, batch)
        if prefixRet < 0 {
            throw LlamaInferenceError.generationFailed("Prefix decode failed (\(prefixRet)).")
        }
        if prefixRet == 1 {
            throw LlamaInferenceError.contextLimitReached("Context full during shared prefix decode.")
        }

        // ── 5. Process each task sequentially: fork → suffix → generate → cleanup ──
        for (taskIdx, task) in tasks.enumerated() {
            if shouldCancel { break }

            let taskSeqId = llama_seq_id(taskIdx + 1)  // seq 1, 2, 3 for tasks 0, 1, 2

            // Fork the shared prefix KV into this task's sequence (O(1) metadata copy).
            llama_memory_seq_cp(mem, 0, taskSeqId, -1, -1)

            let tail = taskTokens[taskIdx][commonLen...]
            var nPos = Int32(commonLen)

            // Decode task-specific suffix tokens into taskSeqId.
            if !tail.isEmpty {
                batch.n_tokens = Int32(tail.count)
                for (i, tok) in tail.enumerated() {
                    batch.token[i]    = tok
                    batch.pos[i]      = nPos + Int32(i)
                    batch.n_seq_id[i] = 1
                    if let sid = batch.seq_id[i] { sid[0] = taskSeqId }
                    batch.logits[i]   = 0
                }
                batch.logits[tail.count - 1] = 1  // logits for last suffix token

                let suffixRet = llama_decode(ctx, batch)
                if suffixRet < 0 {
                    llama_memory_seq_rm(mem, taskSeqId, -1, -1)
                    throw LlamaInferenceError.generationFailed(
                        "Task \(taskIdx) suffix decode failed (\(suffixRet))."
                    )
                }
                if suffixRet == 1 {
                    llama_memory_seq_rm(mem, taskSeqId, -1, -1)
                    throw LlamaInferenceError.contextLimitReached(
                        "Context full during task \(taskIdx) suffix decode."
                    )
                }
                nPos += Int32(tail.count)
            }

            // Build sampler for this task's temperature / strategy.
            var sp = llama_sampler_chain_default_params()
            sp.no_perf = true
            guard let smpl = llama_sampler_chain_init(sp) else {
                llama_memory_seq_rm(mem, taskSeqId, -1, -1)
                throw LlamaInferenceError.generationFailed(
                    "Failed to create sampler for task \(taskIdx)."
                )
            }
            defer { llama_sampler_free(smpl) }

            do {
                try Self.addSamplingStepsToChain(
                    chain: smpl,
                    model: mdl,
                    temperature: task.temperature,
                    grammar: task.grammar,
                    grammarRoot: task.grammarRoot
                )
            } catch {
                llama_memory_seq_rm(mem, taskSeqId, -1, -1)
                throw error
            }

            // Generate output tokens. We sample from -1 (last decoded position) after the suffix
            // decode, then feed each sampled token back via a single-token batch on taskSeqId.
            var output = ""
            var genCount = 0
            var currentToken = llama_sampler_sample(smpl, ctx, -1)

            while genCount < task.maxTokens && !shouldCancel {
                if llama_vocab_is_eog(vocab, currentToken) { break }

                var piece = [CChar](repeating: 0, count: 512)
                var n = llama_token_to_piece(vocab, currentToken, &piece, Int32(piece.count), 0, true)
                if n < 0 {
                    let need = -Int(n)
                    piece = [CChar](repeating: 0, count: need + 1)
                    n = llama_token_to_piece(vocab, currentToken, &piece, Int32(piece.count), 0, true)
                }
                if n > 0 {
                    let clen = min(Int(n), piece.count)
                    if clen < piece.count { piece[clen] = 0 } else { piece[clen - 1] = 0 }
                    output.append(String(cString: piece))
                }

                // Feed sampled token back for the next step (single-token batch on taskSeqId).
                batch.n_tokens      = 1
                batch.token[0]      = currentToken
                batch.pos[0]        = nPos
                batch.n_seq_id[0]   = 1
                if let sid = batch.seq_id[0] { sid[0] = taskSeqId }
                batch.logits[0]     = 1
                nPos += 1
                genCount += 1

                let genRet = llama_decode(ctx, batch)
                if genRet < 0 {
                    // Hard decode error — clean up and propagate; don't deliver partial output.
                    llama_memory_seq_rm(mem, taskSeqId, -1, -1)
                    throw LlamaInferenceError.generationFailed(
                        "Generation decode error during task \(taskIdx) (\(genRet))."
                    )
                }
                if genRet == 1 { break }  // context full — deliver whatever was generated

                currentToken = llama_sampler_sample(smpl, ctx, -1)
            }

            // Remove this task's KV fork before moving to the next task.
            llama_memory_seq_rm(mem, taskSeqId, -1, -1)

            onPartial(output)
        }
    }

    private func makeFormattedChatPrompt(userText: String, model: OpaquePointer) -> String {
        guard let tmplPtr = llama_model_chat_template(model, nil) else {
            return Self.fallbackChatML(userText)
        }
        let template = String(cString: tmplPtr)
        if template.isEmpty {
            return Self.fallbackChatML(userText)
        }

        return "user".withCString { userRole in
            userText.withCString { userContent in
                var message = llama_chat_message(role: userRole, content: userContent)
                var out = [CChar](repeating: 0, count: 256_000)
                let written = withUnsafePointer(to: &message) { msgPtr in
                    template.withCString { tmplC in
                        Int(llama_chat_apply_template(
                            tmplC,
                            msgPtr,
                            1,
                            true,
                            &out,
                            Int32(out.count)
                        ))
                    }
                }
                if written < 0 || written >= out.count {
                    return Self.fallbackChatML(userText)
                }
                out[written] = 0
                guard let s = String(validatingUTF8: out) else {
                    return Self.fallbackChatML(userText)
                }
                if s.isEmpty { return Self.fallbackChatML(userText) }
                return s
            }
        }
    }

    private static func fallbackChatML(_ userText: String) -> String {
        "<|im_start|>user\n\(userText)<|im_end|>\n<|im_start|>assistant\n"
    }

    /// Sampler order: top_k → top_p → temp → optional grammar → dist.
    /// Greedy decoding is used only when temperature is ~0 **and** no grammar is set; grammar forces a minimal positive temperature so constrained decoding participates (bumped value is `0.01`).
    private static func addSamplingStepsToChain(
        chain: UnsafeMutablePointer<llama_sampler>,
        model: OpaquePointer,
        temperature: Double,
        grammar: String?,
        grammarRoot: String
    ) throws {
        let vocab = llama_model_get_vocab(model)

        let tempClamped = max(0.0, min(2.0, temperature))
        let grammarTrimmed = grammar?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasGrammar = !grammarTrimmed.isEmpty
        let useGreedy = tempClamped < 0.0001 && !hasGrammar

        if useGreedy {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
            return
        }

        let effectiveTemp: Float
        if tempClamped < 0.0001, hasGrammar {
            effectiveTemp = 0.01
        } else {
            effectiveTemp = Float(tempClamped)
        }

        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.95, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(effectiveTemp))

        if hasGrammar {
            let rootRaw = grammarRoot.trimmingCharacters(in: .whitespacesAndNewlines)
            let root = rootRaw.isEmpty ? GBNFGrammars.rootRuleName : rootRaw
            let grammarSampler = grammarTrimmed.withCString { gPtr in
                root.withCString { rPtr in
                    llama_sampler_init_grammar(vocab, gPtr, rPtr)
                }
            }
            guard let grammarSampler else {
                throw LlamaInferenceError.generationFailed("GBNF grammar parse failed.")
            }
            llama_sampler_chain_add(chain, grammarSampler)
        }

        llama_sampler_chain_add(chain, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
    }

    private func startTokenizingPrompt(_ formatted: String, options: GenerationOptions) throws {
        guard let ctx = context, let mdl = model else {
            throw LlamaInferenceError.modelNotLoaded
        }
        shouldCancel = false
        releaseGenerationState(freeContext: false)

        if llama_model_has_encoder(mdl) {
            throw LlamaInferenceError.generationFailed(
                "Encoder–decoder models are not supported. Use a decoder-only GGUF."
            )
        }

        let vocab = llama_model_get_vocab(mdl)

        let nTok = formatted.withCString { cstr in
            Int32(-llama_tokenize(vocab, cstr, Int32(strlen(cstr)), nil, 0, false, true))
        }
        guard nTok > 0 else {
            throw LlamaInferenceError.generationFailed("Failed to tokenize the prompt.")
        }
        let promptLimit = max(1, contextLimitTokens - config.promptSlackTokens)
        if Int(nTok) > promptLimit {
            throw LlamaInferenceError.contextLimitReached(
                "The prompt is too long for the current context (\(contextLimitTokens) tokens)."
            )
        }

        let buf = UnsafeMutablePointer<llama_token>.allocate(capacity: Int(nTok))
        let written = formatted.withCString { cstr in
            llama_tokenize(vocab, cstr, Int32(strlen(cstr)), buf, nTok, false, true)
        }
        guard written >= 0 else {
            buf.deallocate()
            throw LlamaInferenceError.generationFailed("Tokenization failed.")
        }

        let mem = llama_get_memory(ctx)
        llama_memory_clear(mem, true)

        decSingleToken = UnsafeMutablePointer<llama_token>.allocate(capacity: 1)

        var sp = llama_sampler_chain_default_params()
        sp.no_perf = true
        guard let smpl = llama_sampler_chain_init(sp) else {
            buf.deallocate()
            decSingleToken?.deallocate()
            decSingleToken = nil
            throw LlamaInferenceError.generationFailed("Failed to create sampler.")
        }
        do {
            try Self.addSamplingStepsToChain(
                chain: smpl,
                model: mdl,
                temperature: options.temperature,
                grammar: options.grammar,
                grammarRoot: options.grammarRoot
            )
        } catch {
            llama_sampler_free(smpl)
            buf.deallocate()
            decSingleToken?.deallocate()
            decSingleToken = nil
            throw error
        }
        generationSampler = smpl

        let ctxLimit = contextLimitTokens
        let capNew = max(0, ctxLimit - Int(nTok) - 1)
        nPredict = min(max(0, options.maxTokens), capNew)
        nPrompt = Int(nTok)
        promptTokenBuffer = buf
        nPos = 0
        lastSampledToken = 0
        hasActiveGeneration = nPredict > 0

        if nPredict == 0 {
            releaseGenerationState(freeContext: false)
            throw LlamaInferenceError.contextLimitReached("No room left in context for a reply.")
        }

        llama_set_abort_callback(ctx, Self.abortTrampoline, Unmanaged.passUnretained(self).toOpaque())
    }

    private func releaseGenerationState(freeContext: Bool) {
        if let ctx = context {
            llama_set_abort_callback(ctx, nil, nil)
        }
        if let s = generationSampler {
            llama_sampler_free(s)
            generationSampler = nil
        }
        promptTokenBuffer?.deallocate()
        promptTokenBuffer = nil
        decSingleToken?.deallocate()
        decSingleToken = nil
        nPos = 0
        nPrompt = 0
        nPredict = 0
        lastSampledToken = 0
        hasActiveGeneration = false

        guard freeContext else { return }
        if let c = context {
            llama_free(c)
            context = nil
        }
        if let m = model {
            llama_model_free(m)
            model = nil
        }
    }
}

#else

nonisolated final class LlamaCppRuntime: @unchecked Sendable, LlamaCppBridge {
    init() {}

    func loadModel(path: String) throws {
        _ = path
        throw LlamaInferenceError.modelLoadFailed(
            "llama.xcframework is not linked. Run setup and open in Xcode."
        )
    }

    func unloadModel() {}

    func countTemplatedUserPromptTokens(_ user: String) throws -> Int {
        _ = user
        throw LlamaInferenceError.modelNotLoaded
    }

    func maxTemplatedPromptTokensForGeneration(_ generationMaxTokens: Int) -> Int {
        // Must match `RuntimeConfig.default.contextWindow` / `promptSlackTokens` when llama is not linked.
        let L = 8192
        let S = 64
        let G = max(1, generationMaxTokens)
        return max(1, min(L - S, L - G - 1))
    }

    func startTemplatedUserPrompt(_ user: String, options: GenerationOptions) throws {
        _ = user
        _ = options
        throw LlamaInferenceError.modelNotLoaded
    }

    func startRawPrompt(_ fullChatPrompt: String, options: GenerationOptions) throws {
        _ = fullChatPrompt
        _ = options
        throw LlamaInferenceError.modelNotLoaded
    }

    func nextTokenChunk() throws -> String? { nil }

    func cancelGeneration() {}

    func generateWithSharedPrefix(
        prefix: String,
        tasks: [SharedPrefixTask],
        onPartial: (String) -> Void
    ) throws {
        _ = prefix
        _ = tasks
        throw LlamaInferenceError.modelNotLoaded
    }
}

#endif
