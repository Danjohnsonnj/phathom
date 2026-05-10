import Foundation
import PhathomCore
import Testing
@testable import Phathom

/// Validates checked-in GBNF sources and that sample payloads still match `LLMJSONExtractor` (no llama load).
@Suite struct GBNFGrammarsTests {

    @Test func grammarSourcesDefineRoot() {
        for (name, g) in [
            ("jsonStringArray", GBNFGrammars.jsonStringArray),
            ("jsonExtractArray", GBNFGrammars.jsonExtractArray),
            ("jsonUUIDStringArray", GBNFGrammars.jsonUUIDStringArray),
        ] {
            #expect(!g.isEmpty, "Empty grammar: \(name)")
            #expect(g.contains("root ::="), "\(name) should declare root")
        }
        #expect(GBNFGrammars.rootRuleName == "root")
    }

    @Test func decodeStringArrayMatchesGrammarShape() {
        let sample = "noise before [\"a\", \"world\"] after"
        let out = LLMJSONExtractor.decodeStringArray(sample)
        #expect(out == ["a", "world"])
    }

    @Test func decodeExtractArrayLabelValueOrder() throws {
        let sample = #"[{"label":"L","value":"V"}]"#
        let out = try #require(LLMJSONExtractor.decodeExtracts(sample))
        #expect(out.count == 1)
        #expect(out[0].label == "L")
        #expect(out[0].value == "V")
    }

    @Test func decodeExtractEmptyArray() {
        let out = LLMJSONExtractor.decodeExtracts("[]")
        #expect(out == [])
    }

    @Test func decodeUUIDStringArraySample() throws {
        let id = "550E8400-E29B-41D4-A716-446655440000"
        let sample = "[\"\(id)\"]"
        let out = try #require(LLMJSONExtractor.decodeStringArray(sample))
        #expect(out.count == 1)
        _ = try #require(UUID(uuidString: out[0]))
    }
}
