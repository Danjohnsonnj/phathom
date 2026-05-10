import Foundation

/// Production GBNF sources for `llama_sampler_init_grammar`.
/// `string` / `ws` follow [`grammars/json.gbnf`](https://github.com/ggml-org/llama.cpp/blob/master/grammars/json.gbnf).
nonisolated enum GBNFGrammars: Sendable {
    /// Passed to `llama_sampler_init_grammar` as `grammar_root` for all grammars below.
    static let rootRuleName = "root"

    /// Top-level JSON array of JSON strings (summary bullets, tags, rank IDs, expanded tags).
    static let jsonStringArray = #"""
    root ::= "[" ws (string ("," ws string)*)? "]" ws
    string ::= "\"" ([^"\\\x7F\x00-\x1F] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4}))* "\"" ws
    ws ::= | " " | "\n" [ \t]{0,20}
    """#

    /// Array of objects with keys `label` and `value` (this order only), string values.
    static let jsonExtractArray = #"""
    root ::= "[" ws (extract-item ("," ws extract-item)*)? "]" ws
    extract-item ::= "{" ws "\"label\"" ws ":" ws string "," ws "\"value\"" ws ":" ws string "}" ws
    string ::= "\"" ([^"\\\x7F\x00-\x1F] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4}))* "\"" ws
    ws ::= | " " | "\n" [ \t]{0,20}
    """#

    /// JSON array of quoted UUID strings (8-4-4-4-12 hex).
    static let jsonUUIDStringArray = #"""
    root ::= "[" ws (uuid-string ("," ws uuid-string)*)? "]" ws
    hex ::= [0-9a-fA-F]
    uuid-string ::= "\"" hex{8} "-" hex{4} "-" hex{4} "-" hex{4} "-" hex{12} "\"" ws
    ws ::= | " " | "\n" [ \t]{0,20}
    """#
}
