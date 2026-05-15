import Foundation

/// Semantic decoration on UTF-16 ranges of the **stripped plain** string (same index space as `MarkdownStripper`).
public struct MarkdownDecorationTraits: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let bold = Self(rawValue: 1 << 0)
    public static let italic = Self(rawValue: 1 << 1)
    public static let inlineCode = Self(rawValue: 1 << 2)
    public static let link = Self(rawValue: 1 << 3)
}

/// One attributed span in plain highlight-anchor space.
public struct MarkdownDecorationRun: Hashable, Sendable {
    public var utf16Range: NSRange
    public var traits: MarkdownDecorationTraits
    public var linkURL: URL?

    public init(utf16Range: NSRange, traits: MarkdownDecorationTraits, linkURL: URL? = nil) {
        self.utf16Range = utf16Range
        self.traits = traits
        self.linkURL = linkURL
    }
}

/// Builds `strippedSourceText`-compatible plain plus decoration runs for UIKit rendering.
public enum MarkdownPlainDecoration {
    /// Same output as `MarkdownStripper.stripMarkdownToPlain` (single pipeline).
    public static func makePlain(from markdown: String) -> String {
        build(from: markdown).plain
    }

    public static func build(from markdown: String) -> (plain: String, runs: [MarkdownDecorationRun]) {
        var s = markdown
        var runs: [MarkdownDecorationRun] = []

        replaceLiteralFencedBlocks(&s, &runs)
        replaceLiteralLinePattern(#"(?m)^[ \t]*`{3}.*$"#, replacement: "\n", options: [], string: &s, runs: &runs)

        applyFirstCaptureGroup(#"!\[([^\]]*)\]\([^)]*\)"#, traits: [], linkFromGroup2: false, string: &s, runs: &runs)
        applyFirstCaptureGroup(#"\[([^\]]*)\]\(([^)]*)\)"#, traits: .link, linkFromGroup2: true, string: &s, runs: &runs)

        replaceHeadingPrefixes(&s, &runs)
        replaceLiteralLinePattern(
            #"^[ \t]*([-*_])\s*\1\s*\1[ \t]*$"#,
            replacement: "\n",
            options: [.anchorsMatchLines],
            string: &s,
            runs: &runs
        )

        applyFirstCaptureGroup(#"`([^`]+)`"#, traits: .inlineCode, linkFromGroup2: false, string: &s, runs: &runs)

        for _ in 0 ..< 8 {
            let before = s
            applyBoldItalicRound(&s, &runs)
            if s == before { break }
        }

        replaceHorizontalWhitespaceRuns(&s, &runs)
        replaceNewlineRuns(&s, &runs)
        return trimResult(s, runs: &runs)
    }

    // MARK: - Pipeline steps

    private static func replaceLiteralFencedBlocks(_ s: inout String, _ runs: inout [MarkdownDecorationRun]) {
        guard let re = try? NSRegularExpression(pattern: #"(?s)```[^`]*```"#, options: []) else { return }
        replaceAllMatchesRTL(regex: re, string: &s, runs: &runs) { _, _ in
            ReplacementPlan(replacement: "\n", innerRange: nil, newRun: nil)
        }
    }

    private static func replaceLiteralLinePattern(
        _ pattern: String,
        replacement: String,
        options: NSRegularExpression.Options,
        string s: inout String,
        runs: inout [MarkdownDecorationRun]
    ) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        replaceAllMatchesRTL(regex: re, string: &s, runs: &runs) { _, _ in
            ReplacementPlan(replacement: replacement, innerRange: nil, newRun: nil)
        }
    }

    private static func replaceHeadingPrefixes(_ s: inout String, _ runs: inout [MarkdownDecorationRun]) {
        guard let re = try? NSRegularExpression(pattern: #"^[ \t]*#{1,6}[ \t]+"#, options: [.anchorsMatchLines]) else {
            return
        }
        replaceAllMatchesRTL(regex: re, string: &s, runs: &runs) { _, _ in
            ReplacementPlan(replacement: "", innerRange: nil, newRun: nil)
        }
    }

    private static func applyFirstCaptureGroup(
        _ pattern: String,
        traits: MarkdownDecorationTraits,
        linkFromGroup2: Bool,
        string s: inout String,
        runs: inout [MarkdownDecorationRun]
    ) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        replaceAllMatchesRTL(regex: re, string: &s, runs: &runs) { result, str in
            let inner = result.range(at: 1)
            guard inner.location != NSNotFound else {
                return ReplacementPlan(replacement: "", innerRange: nil, newRun: nil)
            }
            let repl = (str as NSString).substring(with: inner)
            var newRun: MarkdownDecorationRun?
            if traits.contains(.link), linkFromGroup2 {
                let urlRange = result.range(at: 2)
                let urlStr = urlRange.location != NSNotFound ? (str as NSString).substring(with: urlRange) : ""
                let encoded = urlStr.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
                let url = URL(string: urlStr) ?? URL(string: encoded)
                newRun = MarkdownDecorationRun(utf16Range: NSRange(location: result.range.location, length: (repl as NSString).length), traits: .link, linkURL: url)
            } else if !traits.isEmpty {
                newRun = MarkdownDecorationRun(utf16Range: NSRange(location: result.range.location, length: (repl as NSString).length), traits: traits, linkURL: nil)
            }
            return ReplacementPlan(replacement: repl, innerRange: inner, newRun: newRun)
        }
    }

    private static func applyBoldItalicRound(_ s: inout String, _ runs: inout [MarkdownDecorationRun]) {
        applyFirstCaptureGroup(#"\*\*([^*]+)\*\*"#, traits: .bold, linkFromGroup2: false, string: &s, runs: &runs)
        applyFirstCaptureGroup(#"__([^_]+)__"#, traits: .bold, linkFromGroup2: false, string: &s, runs: &runs)
        applyFirstCaptureGroup(#"(?<!\*)\*(?!\*)([^*]+)\*(?!\*)"#, traits: .italic, linkFromGroup2: false, string: &s, runs: &runs)
        applyFirstCaptureGroup(#"(?<!_)_(?!_)([^_\n]+)_(?!_)"#, traits: .italic, linkFromGroup2: false, string: &s, runs: &runs)
    }

    private static func replaceHorizontalWhitespaceRuns(_ s: inout String, _ runs: inout [MarkdownDecorationRun]) {
        guard let re = try? NSRegularExpression(pattern: #"[\t ]+"#, options: []) else { return }
        replaceAllMatchesRTL(regex: re, string: &s, runs: &runs) { _, _ in
            ReplacementPlan(replacement: " ", innerRange: nil, newRun: nil)
        }
    }

    private static func replaceNewlineRuns(_ s: inout String, _ runs: inout [MarkdownDecorationRun]) {
        guard let re = try? NSRegularExpression(pattern: #"\n{3,}"#, options: []) else { return }
        replaceAllMatchesRTL(regex: re, string: &s, runs: &runs) { _, _ in
            ReplacementPlan(replacement: "\n\n", innerRange: nil, newRun: nil)
        }
    }

    // MARK: - RTL replacement core

    private struct ReplacementPlan {
        var replacement: String
        /// When replacing with first capture, inner range in **pre-replacement** string coordinates.
        var innerRange: NSRange?
        var newRun: MarkdownDecorationRun?
    }

    private static func replaceAllMatchesRTL(
        regex: NSRegularExpression,
        string s: inout String,
        runs: inout [MarkdownDecorationRun],
        plan: (NSTextCheckingResult, String) -> ReplacementPlan
    ) {
        let full = NSRange(location: 0, length: (s as NSString).length)
        let matches = regex.matches(in: s, options: [], range: full)
        guard !matches.isEmpty else { return }

        for result in matches.reversed() {
            let current = s as NSString
            let planResult = plan(result, s)
            let matchRange = result.range
            guard matchRange.location != NSNotFound, NSMaxRange(matchRange) <= current.length else { continue }
            let repl = planResult.replacement
            let rLen = (repl as NSString).length

            mapRunsForReplacement(
                runs: &runs,
                matchStart: matchRange.location,
                matchEnd: NSMaxRange(matchRange),
                replacementLength: rLen,
                innerRange: planResult.innerRange
            )

            let newStr = current.replacingCharacters(in: matchRange, with: repl)
            s = newStr as String

            if var nr = planResult.newRun {
                nr.utf16Range = NSRange(location: matchRange.location, length: rLen)
                coalesceInsert(&runs, nr)
            }
        }
    }

    /// Map decoration runs when `[matchStart, matchEnd)` becomes `replacementLength` UTF-16 units.
    private static func mapRunsForReplacement(
        runs: inout [MarkdownDecorationRun],
        matchStart: Int,
        matchEnd: Int,
        replacementLength: Int,
        innerRange: NSRange?
    ) {
        let delta = replacementLength - (matchEnd - matchStart)
        var out: [MarkdownDecorationRun] = []
        out.reserveCapacity(runs.count)

        for var run in runs {
            let rs = run.utf16Range.location
            let reEnd = NSMaxRange(run.utf16Range)

            if reEnd <= matchStart {
                out.append(run)
            } else if rs >= matchEnd {
                run.utf16Range.location += delta
                out.append(run)
            } else if let ir = innerRange, ir.location != NSNotFound {
                let i0 = ir.location
                let i1 = NSMaxRange(ir)
                let lo = max(rs, i0)
                let hi = min(reEnd, i1)
                if hi > lo {
                    run.utf16Range = NSRange(location: matchStart + (lo - i0), length: hi - lo)
                    out.append(run)
                }
            }
            // literal replace or purely markup overlap: drop
        }
        runs = out
    }

    private static func coalesceInsert(_ runs: inout [MarkdownDecorationRun], _ newRun: MarkdownDecorationRun) {
        runs.append(newRun)
    }

    private static func trimResult(_ s: String, runs: inout [MarkdownDecorationRun]) -> (plain: String, runs: [MarkdownDecorationRun]) {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", []) }
        if s == trimmed {
            return (trimmed, runs)
        }
        guard let swiftRange = s.range(of: trimmed) else { return (trimmed, []) }
        let lead = s.utf16.distance(
            from: s.utf16.startIndex,
            to: swiftRange.lowerBound.samePosition(in: s.utf16)!
        )
        let tLen = (trimmed as NSString).length

        var out: [MarkdownDecorationRun] = []
        for var run in runs {
            let rs = run.utf16Range.location
            let reEnd = NSMaxRange(run.utf16Range)
            if reEnd <= lead || rs >= lead + tLen { continue }
            var nr = max(0, rs - lead)
            var nl = run.utf16Range.length
            if rs < lead {
                nl -= lead - rs
                nr = 0
            }
            if nr + nl > tLen {
                nl = tLen - nr
            }
            if nl <= 0 { continue }
            run.utf16Range = NSRange(location: nr, length: nl)
            out.append(run)
        }
        return (trimmed, out)
    }
}
