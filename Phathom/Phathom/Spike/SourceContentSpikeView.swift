#if DEBUG
import MarkdownUI
import SwiftUI

/// DEBUG-only host for `docs/handoff/real-markdown-highlights-spike.md` checklist.
struct SourceContentSpikeView: View {
    @State private var logLines: [String] = []
    @State private var lastPayload: SourceContentSelectionPayload?
    @State private var selfTestSummary: String?
    @State private var showCollapsed = false
    @State private var applySampleHighlight = true
    @State private var fixtureCoordinator: SourceContentSpikeWebView.Coordinator?

    private var fixtureHTML: String {
        SourceContentSpikeFixtures.wrapDocument(
            body: SourceContentSpikeFixtures.fixtureBodyHTML,
            collapsed: showCollapsed
        )
    }

    var body: some View {
        List {
            Section("Fixture WKWebView") {
                SourceContentSpikeWebView(
                    html: fixtureHTML,
                    applyHighlightsOnLoad: applySampleHighlight
                        ? [SourceContentSpikeFixtures.sampleHighlightRange]
                        : [],
                    onSelectionChange: { payload in
                        lastPayload = payload
                        if let payload {
                            appendLog("selection start=\(payload.start) end=\(payload.end) text=\(payload.text)")
                        }
                    },
                    onHighlightTap: { id in
                        appendLog("highlight tap \(id)")
                    },
                    onLog: { appendLog($0) },
                    onCoordinatorReady: { fixtureCoordinator = $0 }
                )
                .frame(minHeight: 280)

                Toggle("Collapsed clip (~8 lines)", isOn: $showCollapsed)
                Toggle("Apply sample overlay on load", isOn: $applySampleHighlight)
            }

            Section("Automated JS checks") {
                if let selfTestSummary {
                    Text(selfTestSummary)
                        .font(.caption)
                        .foregroundStyle(
                            selfTestSummary.contains("failed") ? AppPalette.accent : AppPalette.textSecondary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Run phathomSpikeSelfTest") {
                    applySampleHighlight = false
                    runSelfTest()
                }
                Text("Per-test lines appear in Log below.")
                    .font(.caption2)
                    .foregroundStyle(AppPalette.textTertiary)
            }

            Section("Last selection") {
                if let lastPayload {
                    Text("UTF-16 [\(lastPayload.start), \(lastPayload.end))")
                    Text("\"\(lastPayload.text)\"")
                        .font(.body.monospaced())
                } else {
                    Text("Select text in web view")
                        .foregroundStyle(AppPalette.textTertiary)
                }
            }

            Section("Parity — MarkdownUI (A)") {
                Markdown(SourceContentSpikeFixtures.parityMarkdown)
                    .markdownTheme(.phathomNote)
            }

            Section("Parity — WK HTML (B)") {
                SourceContentSpikeWebView(
                    html: SourceContentSpikeFixtures.wrapDocument(
                        body: SourceContentSpikeFixtures.parityBodyHTML
                    ),
                    applyHighlightsOnLoad: [],
                    onSelectionChange: { _ in },
                    onHighlightTap: { _ in },
                    onLog: { _ in }
                )
                .frame(minHeight: 320)
            }

            Section("Log") {
                ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2.monospaced())
                }
            }
        }
        .navigationTitle("Source spike")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func appendLog(_ line: String) {
        logLines.insert(line, at: 0)
        if logLines.count > 40 { logLines.removeLast() }
    }

    private func runSelfTest() {
        appendLog("running self-test…")
        guard let fixtureCoordinator else {
            selfTestSummary = "Web view not ready"
            return
        }
        fixtureCoordinator.runSelfTest { result in
            if let error = result["error"] as? String {
                selfTestSummary = "FAIL: \(error)"
                appendLog(selfTestSummary!)
                return
            }
            guard let tests = result["tests"] as? [[String: Any]] else {
                selfTestSummary = "FAIL: malformed result"
                return
            }
            let failed = tests.filter { !SelfTestResult.isPass($0["pass"]) }
            for t in tests {
                let name = t["name"] as? String ?? "?"
                let pass = SelfTestResult.isPass(t["pass"])
                let detail = t["detail"] as? String ?? ""
                appendLog("\(pass ? "PASS" : "FAIL") \(name) \(detail)")
            }
            if failed.isEmpty {
                selfTestSummary = "All \(tests.count) JS checks passed"
            } else {
                let names = failed.compactMap { $0["name"] as? String }.joined(separator: ", ")
                selfTestSummary = "\(failed.count)/\(tests.count) failed: \(names)"
            }
        }
    }
}

private enum SelfTestResult {
    static func isPass(_ value: Any?) -> Bool {
        if let pass = value as? Bool { return pass }
        if let n = value as? NSNumber { return n.boolValue }
        if let n = value as? Int { return n != 0 }
        return false
    }
}

#Preview {
    NavigationStack {
        SourceContentSpikeView()
    }
}
#endif
