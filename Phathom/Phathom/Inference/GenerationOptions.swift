import PhathomCore
import Foundation

/// One decode task after a shared chat prefix (KV copy per task).
nonisolated struct SharedPrefixTask: Sendable {
    var suffix: String
    var maxTokens: Int
    var temperature: Double
    /// Full GBNF source; `nil` or empty string leaves decoding unconstrained.
    var grammar: String?
    /// Start symbol for `llama_sampler_init_grammar` (usually `root`).
    var grammarRoot: String

    nonisolated init(
        suffix: String,
        maxTokens: Int,
        temperature: Double,
        grammar: String? = nil,
        grammarRoot: String = GBNFGrammars.rootRuleName
    ) {
        self.suffix = suffix
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.grammar = grammar
        self.grammarRoot = grammarRoot
    }
}

nonisolated struct GenerationOptions: Sendable {
    var maxTokens: Int
    var temperature: Double
    /// Full GBNF source; `nil` or empty string leaves streaming decode unconstrained.
    var grammar: String?
    var grammarRoot: String

    nonisolated init(
        maxTokens: Int = 512,
        temperature: Double = 0.2,
        grammar: String? = nil,
        grammarRoot: String = GBNFGrammars.rootRuleName
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.grammar = grammar
        self.grammarRoot = grammarRoot
    }
}
