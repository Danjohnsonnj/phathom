import Foundation
import PhathomCore

#if DEBUG && canImport(llama)

import CoreGraphics
import llama

/// Phase 0: on-device VLM spike (`text GGUF` + mmproj + JPEG). Production pipeline gated until Phase 0 complete.
struct VisionSpikeResult: Sendable {
    let description: String
    let loadDuration: TimeInterval
    let evalDuration: TimeInterval
    let generateDuration: TimeInterval
    let totalDuration: TimeInterval
    let supportsVision: Bool
    let profile: VisionSpikeProfile
    let runtimeAttempt: VisionSpikeRuntimeAttempt
    let imageMaxDimensionApplied: CGFloat
    /// Always `true` on device spike (Metal projector encode).
    let useGPUProjector: Bool
    /// Token count helper over vision+text chunks after `mtmd_tokenize` (`nil` if unavailable).
    let estimatedVisionSequenceTokens: UInt?
}

enum VisionSpikeError: LocalizedError, Sendable {
    /// Security-scoped bookmark could not be opened (`VisionSpikeSettingsSection` prefetch / run).
    case ggufBookmarksUnavailable

    case modelLoadFailed(String)
    case visionInitFailed(String)
    case imageDecodeFailed
    case tokenizeFailed(Int32)
    case evalFailed(Int32)
    case generationFailed(String)
    case visionNotSupported
    /// UI / task watchdog — surfaced when spike exceeds allotted wall time (no native unwind).
    case timeout

    var errorDescription: String? {
        switch self {
        case .ggufBookmarksUnavailable:
            "Could not resolve vision spike GGUF bookmarks. Re-pick text GGUF and mmproj."

        case .modelLoadFailed(let s): "Model load failed: \(s)"
        case .visionInitFailed(let s): "Vision projector failed: \(s)"
        case .imageDecodeFailed: "Could not decode image bytes for vision input."
        case .tokenizeFailed(let code): "Vision tokenize failed (code \(code))."
        case .evalFailed(let code): "Vision eval failed (code \(code))."
        case .generationFailed(let s): "Generation failed: \(s)"
        case .visionNotSupported: "Loaded mmproj does not report vision support."
        case .timeout:
            "Vision spike timed out. Try smaller image profile, tighter Capable preset, or relaunch fresh."
        }
    }
}

nonisolated final class LlamaVisionSpike: @unchecked Sendable {

    /// Max completion tokens — short caption for spike validation.
    private static let spikeMaxNewTokens = 384
    private static let spikeTemperature: Float = 0.2

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var mtmdCtx: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?

    deinit {
        releaseAll()
    }

    func describeImage(
        textModelPath: String,
        mmprojPath: String,
        jpegData: Data,
        mergedProfile: VisionSpikeProfile,
        userPrompt: String? = nil
    ) throws -> VisionSpikeResult {
        let primary = VisionSpikeRunConfiguration.primary(for: mergedProfile)
        let tightened = VisionSpikeRunConfiguration.tightenedFallback(for: mergedProfile)

        guard let tightened else {
            return try describeSingleAttempt(
                textModelPath: textModelPath,
                mmprojPath: mmprojPath,
                jpegData: jpegData,
                configuration: primary,
                userPrompt: userPrompt
            )
        }

        do {
            return try describeSingleAttempt(
                textModelPath: textModelPath,
                mmprojPath: mmprojPath,
                jpegData: jpegData,
                configuration: primary,
                userPrompt: userPrompt
            )
        } catch {
            // Capable preset: automatic tightened retry (§5 — smaller px + fewer image tokens).
            return try describeSingleAttempt(
                textModelPath: textModelPath,
                mmprojPath: mmprojPath,
                jpegData: jpegData,
                configuration: tightened,
                userPrompt: userPrompt
            )
        }
    }

    /// Internal single-shot run for one `VisionSpikeRunConfiguration`.
    private func describeSingleAttempt(
        textModelPath: String,
        mmprojPath: String,
        jpegData: Data,
        configuration: VisionSpikeRunConfiguration,
        userPrompt: String?
    ) throws -> VisionSpikeResult {

        guard let resizedJPEG = MediaImageEncoding.normalizedJPEG(
            from: jpegData,
            maxDimension: configuration.imageMaxDimensionPixels,
            quality: 0.82
        ), !resizedJPEG.isEmpty else {
            throw VisionSpikeError.imageDecodeFailed
        }

        releaseAll()
        let totalStart = CFAbsoluteTimeGetCurrent()
        var loadDuration: TimeInterval = 0
        var evalDuration: TimeInterval = 0
        var generateDuration: TimeInterval = 0

        ggml_backend_load_all()

        let loadStart = CFAbsoluteTimeGetCurrent()
        try loadTextModel(path: textModelPath, configuration: configuration)
        loadDuration += CFAbsoluteTimeGetCurrent() - loadStart

        let visionStart = CFAbsoluteTimeGetCurrent()
        try loadVisionProjector(mmprojPath: mmprojPath, configuration: configuration)
        loadDuration += CFAbsoluteTimeGetCurrent() - visionStart

        guard let vision = mtmdCtx, mtmd_support_vision(vision) else {
            throw VisionSpikeError.visionNotSupported
        }

        let marker = String(cString: mtmd_default_marker())
        let basePrompt =
            userPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? userPrompt!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Describe this image in detail for a personal knowledge library. Include subjects, scene, mood, and any visible text."
        let userBody = "\(marker)\n\(basePrompt)"
        let formatted = formatUserPrompt(userBody)

        guard let bitmap = resizedJPEG.withUnsafeBytes({ raw -> OpaquePointer? in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            return mtmd_helper_bitmap_init_from_buf(vision, base, raw.count)
        }) else {
            throw VisionSpikeError.imageDecodeFailed
        }
        defer { mtmd_bitmap_free(bitmap) }

        guard let chunks = mtmd_input_chunks_init() else {
            throw VisionSpikeError.tokenizeFailed(-1)
        }
        defer { mtmd_input_chunks_free(chunks) }

        let tokenizeResult: Int32 = formatted.withCString { formattedC in
            var text = mtmd_input_text(
                text: formattedC,
                add_special: true,
                parse_special: true
            )
            var bmpPtr: OpaquePointer? = bitmap
            return withUnsafePointer(to: &text) { textPtr in
                withUnsafeMutablePointer(to: &bmpPtr) { bmpArray in
                    mtmd_tokenize(vision, chunks, textPtr, bmpArray, 1)
                }
            }
        }
        guard tokenizeResult == 0 else {
            throw VisionSpikeError.tokenizeFailed(tokenizeResult)
        }

        let nTokensEstimated = UInt(mtmd_helper_get_n_tokens(chunks))

        guard let ctx = context else {
            throw VisionSpikeError.generationFailed("Missing llama context.")
        }
        let nBatch = Int32(min(512, configuration.spikeContextWindow))
        var nPast: llama_pos = 0

        let evalStart = CFAbsoluteTimeGetCurrent()
        let evalCode = mtmd_helper_eval_chunks(
            vision,
            ctx,
            chunks,
            nPast,
            0,
            nBatch,
            true,
            &nPast
        )
        evalDuration = CFAbsoluteTimeGetCurrent() - evalStart
        guard evalCode == 0 else {
            throw VisionSpikeError.evalFailed(evalCode)
        }

        let genStart = CFAbsoluteTimeGetCurrent()
        let description = try generateDescription(nPast: nPast, maxTokens: Self.spikeMaxNewTokens)
        generateDuration = CFAbsoluteTimeGetCurrent() - genStart

        let totalDuration = CFAbsoluteTimeGetCurrent() - totalStart
        return VisionSpikeResult(
            description: description,
            loadDuration: loadDuration,
            evalDuration: evalDuration,
            generateDuration: generateDuration,
            totalDuration: totalDuration,
            supportsVision: true,
            profile: configuration.profile,
            runtimeAttempt: configuration.runtimeAttempt,
            imageMaxDimensionApplied: configuration.imageMaxDimensionPixels,
            useGPUProjector: true,
            estimatedVisionSequenceTokens: nTokensEstimated == 0 ? nil : nTokensEstimated
        )
    }

    private func loadTextModel(path: String, configuration: VisionSpikeRunConfiguration) throws {
        var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
#else
        modelParams.n_gpu_layers = -1
#endif

        guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
            throw VisionSpikeError.modelLoadFailed("llama.cpp could not load text GGUF.")
        }

        var contextParams = llama_context_default_params()
        let trainCtx = Int(llama_model_n_ctx_train(loadedModel))
        let requestedCtx = configuration.spikeContextWindow
        let effectiveCtx: UInt32
        if trainCtx > 0 {
            effectiveCtx = min(requestedCtx, UInt32(clamping: trainCtx))
        } else {
            effectiveCtx = requestedCtx
        }

        contextParams.n_ctx = effectiveCtx
        contextParams.n_batch = effectiveCtx
        contextParams.n_ubatch = min(configuration.physicalBatchUBatch, effectiveCtx)
        contextParams.n_seq_max = 1
        contextParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED
        contextParams.offload_kqv = true
        contextParams.kv_unified = false

        let nThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        contextParams.n_threads = Int32(nThreads)
        contextParams.n_threads_batch = Int32(nThreads)

        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            throw VisionSpikeError.modelLoadFailed("Unable to initialize llama context.")
        }
        model = loadedModel
        context = loadedContext
    }

    private func loadVisionProjector(mmprojPath: String, configuration: VisionSpikeRunConfiguration) throws {
        guard let mdl = model else {
            throw VisionSpikeError.modelLoadFailed("Text model not loaded.")
        }
        var params = mtmd_context_params_default()

        params.use_gpu = true
        params.print_timings = false
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
        params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED
        params.warmup = false

        if let cap = configuration.imageMaxTokens {
            params.image_max_tokens = Int32(cap)
        }

        guard let ctx = mtmd_init_from_file(mmprojPath, mdl, params) else {
            throw VisionSpikeError.visionInitFailed("mtmd_init_from_file returned nil — check mmproj matches text GGUF.")
        }
        mtmdCtx = ctx
    }

    private func formatUserPrompt(_ userBody: String) -> String {
        guard let mdl = model else { return Self.fallbackChatML(userBody) }
        guard let tmplPtr = llama_model_chat_template(mdl, nil) else {
            return Self.fallbackChatML(userBody)
        }
        let template = String(cString: tmplPtr)
        if template.isEmpty { return Self.fallbackChatML(userBody) }

        return userBody.withCString { userContent in
            "user".withCString { userRole in
                var message = llama_chat_message(role: userRole, content: userContent)
                var out = [CChar](repeating: 0, count: 256_000)
                let written = template.withCString { tmplC in
                    withUnsafePointer(to: &message) { msgPtr in
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
                guard written > 0, written < out.count else {
                    return Self.fallbackChatML(userBody)
                }
                out[written] = 0
                guard let s = String(validatingUTF8: out), !s.isEmpty else {
                    return Self.fallbackChatML(userBody)
                }
                return s
            }
        }
    }

    private func generateDescription(nPast: llama_pos, maxTokens: Int) throws -> String {
        guard let ctx = context, let mdl = model else {
            throw VisionSpikeError.generationFailed("Context not ready.")
        }
        let vocab = llama_model_get_vocab(mdl)
        try setupSampler()

        var output = ""
        var pos = nPast
        var generated = 0

        while generated < maxTokens {
            guard let smpl = sampler else { break }
            let token = llama_sampler_sample(smpl, ctx, -1)
            if llama_vocab_is_eog(vocab, token) { break }

            var piece = [CChar](repeating: 0, count: 512)
            var n = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, true)
            if n < 0 {
                let need = -Int(n)
                piece = [CChar](repeating: 0, count: need + 1)
                n = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, true)
            }
            if n > 0 {
                let clen = min(Int(n), piece.count)
                if clen < piece.count { piece[clen] = 0 } else { piece[clen - 1] = 0 }
                if let chunk = String(validatingUTF8: piece) {
                    output += chunk
                }
            }

            var tokenBuf = token
            let batch = llama_batch_get_one(&tokenBuf, 1)
            let dret = llama_decode(ctx, batch)
            if dret != 0 { break }
            pos += 1
            generated += 1
            llama_sampler_accept(smpl, token)
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VisionSpikeError.generationFailed("Model returned empty description.")
        }
        return trimmed
    }

    private func setupSampler() throws {
        guard sampler == nil else { return }
        var sp = llama_sampler_chain_default_params()
        sp.no_perf = true
        guard let smpl = llama_sampler_chain_init(sp) else {
            throw VisionSpikeError.generationFailed("Failed to create sampler.")
        }
        let temp = Self.spikeTemperature
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(temp))
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
        sampler = smpl
    }

    private func releaseAll() {
        if let s = sampler {
            llama_sampler_free(s)
            sampler = nil
        }
        if let v = mtmdCtx {
            mtmd_free(v)
            mtmdCtx = nil
        }
        if let c = context {
            llama_free(c)
            context = nil
        }
        if let m = model {
            llama_model_free(m)
            model = nil
        }
    }

    private static func fallbackChatML(_ userText: String) -> String {
        "<|im_start|>user\n\(userText)<|im_end|>\n<|im_start|>assistant\n"
    }
}

#elseif DEBUG && !canImport(llama)

import CoreGraphics

struct VisionSpikeResult: Sendable {
    let description: String
    let loadDuration: TimeInterval
    let evalDuration: TimeInterval
    let generateDuration: TimeInterval
    let totalDuration: TimeInterval
    let supportsVision: Bool
    let profile: VisionSpikeProfile
    let runtimeAttempt: VisionSpikeRuntimeAttempt
    let imageMaxDimensionApplied: CGFloat
    let useGPUProjector: Bool
    let estimatedVisionSequenceTokens: UInt?
}

enum VisionSpikeError: LocalizedError, Sendable {
    case frameworkMissing
    case ggufBookmarksUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .frameworkMissing:
            "llama.xcframework with mtmd is not linked. Run scripts/rebuild-llama-xcframework-with-mtmd.sh."
        case .ggufBookmarksUnavailable:
            "Could not resolve vision spike GGUF bookmarks. Re-pick text GGUF and mmproj."

        case .timeout:
            "Vision spike timed out."
        }
    }
}

nonisolated final class LlamaVisionSpike: @unchecked Sendable {
    func describeImage(
        textModelPath: String,
        mmprojPath: String,
        jpegData: Data,
        mergedProfile _: VisionSpikeProfile,
        userPrompt: String? = nil
    ) throws -> VisionSpikeResult {
        _ = textModelPath
        _ = mmprojPath
        _ = jpegData
        _ = userPrompt
        throw VisionSpikeError.frameworkMissing
    }
}

#else

nonisolated final class LlamaVisionSpike: @unchecked Sendable {}

#endif
