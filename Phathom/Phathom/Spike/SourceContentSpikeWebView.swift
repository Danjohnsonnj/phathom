#if DEBUG
import SwiftUI
import WebKit

struct SourceContentSelectionPayload: Equatable {
    var start: Int
    var end: Int
    var text: String
}

struct SourceContentSpikeWebView: UIViewRepresentable {
    var html: String
    var applyHighlightsOnLoad: [(start: Int, end: Int, id: String)]
    var onSelectionChange: (SourceContentSelectionPayload?) -> Void
    var onHighlightTap: (String) -> Void
    var onLog: (String) -> Void
    var onCoordinatorReady: ((Coordinator) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionChange: onSelectionChange,
            onHighlightTap: onHighlightTap,
            onLog: onLog
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        let script = WKUserScript(
            source: SourceContentSpikeScript.javaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(script)
        controller.add(context.coordinator, name: "phathomSelection")
        controller.add(context.coordinator, name: "phathomHighlightTap")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator

        let editMenu = UIEditMenuInteraction(delegate: context.coordinator)
        webView.addInteraction(editMenu)
        context.coordinator.editMenuInteraction = editMenu
        context.coordinator.webView = webView
        DispatchQueue.main.async {
            onCoordinatorReady?(context.coordinator)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onHighlightTap = onHighlightTap
        context.coordinator.onLog = onLog

        let fingerprint = html.hashValue ^ applyHighlightsOnLoad.map { "\($0.start)-\($0.end)-\($0.id)" }.joined().hashValue
        guard context.coordinator.loadedFingerprint != fingerprint else { return }
        context.coordinator.loadedFingerprint = fingerprint
        context.coordinator.pendingHighlights = applyHighlightsOnLoad
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIEditMenuInteractionDelegate {
        var onSelectionChange: (SourceContentSelectionPayload?) -> Void
        var onHighlightTap: (String) -> Void
        var onLog: (String) -> Void

        weak var webView: WKWebView?
        var editMenuInteraction: UIEditMenuInteraction?
        var loadedFingerprint: Int?
        var pendingHighlights: [(start: Int, end: Int, id: String)] = []
        private(set) var lastSelectionPayload: SourceContentSelectionPayload?

        init(
            onSelectionChange: @escaping (SourceContentSelectionPayload?) -> Void,
            onHighlightTap: @escaping (String) -> Void,
            onLog: @escaping (String) -> Void
        ) {
            self.onSelectionChange = onSelectionChange
            self.onHighlightTap = onHighlightTap
            self.onLog = onLog
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "phathomSelection":
                if let raw = message.body as? String, let data = raw.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let start = json["start"] as? Int,
                   let end = json["end"] as? Int,
                   let text = json["text"] as? String {
                    let payload = SourceContentSelectionPayload(start: start, end: end, text: text)
                    lastSelectionPayload = payload
                    onSelectionChange(payload)
                } else {
                    lastSelectionPayload = nil
                    onSelectionChange(nil)
                }
            case "phathomHighlightTap":
                if let id = message.body as? String {
                    onLog("tap highlight id=\(id)")
                    onHighlightTap(id)
                }
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !pendingHighlights.isEmpty else { return }
            let ranges: [[String: Any]] = pendingHighlights.map {
                ["start": $0.start, "end": $0.end, "id": $0.id]
            }
            guard let data = try? JSONSerialization.data(withJSONObject: ranges),
                  let json = String(data: data, encoding: .utf8) else { return }
            let js = "phathomApplyHighlights(\(json));"
            webView.callAsyncJavaScript(js, in: nil, in: .page) { [weak self] result in
                switch result {
                case .success:
                    self?.onLog("applied \(ranges.count) highlight overlay(s)")
                case .failure(let error):
                    self?.onLog("overlay error: \(error.localizedDescription)")
                }
            }
            pendingHighlights = []
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            var children = suggestedActions
            if let payload = lastSelectionPayload {
                let captured = payload
                let action = UIAction(title: "Highlight") { [weak self] _ in
                    self?.onLog("Highlight action start=\(captured.start) end=\(captured.end) text=\(captured.text)")
                    self?.onSelectionChange(captured)
                }
                children.append(action)
            }
            return UIMenu(children: children)
        }

        func runSelfTest(completion: @escaping ([String: Any]) -> Void) {
            guard let webView else { return }
            let expectationsJSON = SourceContentSpikeFixtures.selfTestExpectationsJSON
            // evaluateJavaScript + JSON string avoids callAsyncJavaScript bridging Optional<Any>.
            let script = """
            (function() {
              try {
                var expectations = \(expectationsJSON);
                return JSON.stringify(phathomSpikeSelfTest(expectations));
              } catch (e) {
                return JSON.stringify([{ name: 'js_error', pass: false, detail: String(e) }]);
              }
            })();
            """
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    completion(["error": error.localizedDescription])
                    return
                }
                if let arr = Self.parseSelfTestResults(value) {
                    completion(["tests": arr])
                    return
                }
                let kind = value.map { String(describing: type(of: $0)) } ?? "nil"
                completion(["error": "bad self-test payload (\(kind))"])
            }
        }

        private static func parseSelfTestResults(_ value: Any?) -> [[String: Any]]? {
            let unwrapped = unwrapAny(value)
            if let raw = unwrapped as? String,
               let data = raw.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                return parseSelfTestRows(parsed)
            }
            return parseSelfTestRows(unwrapped)
        }

        private static func parseSelfTestRows(_ value: Any?) -> [[String: Any]]? {
            if let arr = value as? [[String: Any]] { return normalizeRows(arr) }
            if let arr = value as? [Any] {
                let rows = arr.compactMap { row -> [String: Any]? in
                    if let dict = row as? [String: Any] { return dict }
                    if let dict = row as? NSDictionary { return dict as? [String: Any] }
                    return nil
                }
                return normalizeRows(rows)
            }
            if let nsArr = value as? NSArray {
                let rows = nsArr.compactMap { row -> [String: Any]? in
                    if let dict = row as? [String: Any] { return dict }
                    if let dict = row as? NSDictionary { return dict as? [String: Any] }
                    return nil
                }
                return normalizeRows(rows)
            }
            return nil
        }

        private static func normalizeRows(_ rows: [[String: Any]]) -> [[String: Any]]? {
            guard !rows.isEmpty else { return nil }
            return rows
        }

        private static func unwrapAny(_ value: Any?) -> Any? {
            var current: Any? = value
            while let c = current {
                let mirror = Mirror(reflecting: c)
                guard mirror.displayStyle == .optional else { return c }
                guard let child = mirror.children.first else { return nil }
                current = child.value
            }
            return nil
        }
    }
}
#endif
