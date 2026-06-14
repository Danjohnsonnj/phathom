#if os(macOS)
import CryptoKit
import PhathomCore
import SwiftUI
import WebKit

/// WKWebView reports `.zero` intrinsic size; SwiftUI would otherwise give it no height.
private final class IntrinsicHeightWebView: WKWebView {
    private var measuredHeight: CGFloat = 120

    weak var highlightCoordinator: HighlightableMarkdownWebView.Coordinator?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: measuredHeight)
    }

    func applyMeasuredHeight(_ height: CGFloat) {
        let clamped = max(44, height)
        guard abs(clamped - measuredHeight) > 0.5 else { return }
        measuredHeight = clamped
        invalidateIntrinsicContentSize()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard let coord = highlightCoordinator,
              coord.selectionActive.wrappedValue
        else {
            return menu
        }
        let fallback = coord.lastSelectionPayload
        let highlightItem = NSMenuItem(
            title: "Highlight",
            action: #selector(highlightSelectedText(_:)),
            keyEquivalent: ""
        )
        highlightItem.target = self
        highlightItem.representedObject = fallback
        if !menu.items.isEmpty {
            menu.addItem(.separator())
        }
        menu.addItem(highlightItem)
        return menu
    }

    @objc private func highlightSelectedText(_ sender: NSMenuItem) {
        let fallback = sender.representedObject as? HighlightableMarkdownWebView.Coordinator.SelectionPayload
        highlightCoordinator?.commitHighlightFromLiveSelection(fallback: fallback)
    }

    /// Content is sized to full document height; parent `ScrollView` owns vertical scroll.
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

struct HighlightableMarkdownWebView: NSViewRepresentable {
    @Binding var selectionActive: Bool
    @Binding var highlightApplyToken: Int

    var sourceHTML: String
    var highlights: [Highlight]
    var collapsed: Bool
    var onCreateHighlight: (String, Int?) -> Void
    var onTapHighlight: (Highlight) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectionActive: $selectionActive,
            highlightApplyToken: $highlightApplyToken,
            highlights: highlights,
            onCreateHighlight: onCreateHighlight,
            onTapHighlight: onTapHighlight
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()

        let script = WKUserScript(
            source: HighlightableMarkdownWebViewScript.javaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(script)
        controller.add(context.coordinator, name: "phathomSelection")
        controller.add(context.coordinator, name: "phathomHighlightTap")
        config.userContentController = controller

        let webView = IntrinsicHeightWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        Self.disableScrolling(in: webView)
        webView.navigationDelegate = context.coordinator
        webView.highlightCoordinator = context.coordinator
        context.coordinator.webView = webView

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.selectionActive = $selectionActive
        context.coordinator.highlightApplyTokenBinding = $highlightApplyToken
        context.coordinator.collapsed = collapsed
        context.coordinator.highlights = highlights
        context.coordinator.onCreateHighlight = onCreateHighlight
        context.coordinator.onTapHighlight = onTapHighlight

        if let intrinsicWebView = webView as? IntrinsicHeightWebView {
            intrinsicWebView.highlightCoordinator = context.coordinator
        }

        let highlightKey = Coordinator.highlightKey(for: highlights)
        let bodyKey = "\(Self.stableFingerprint(sourceHTML))_\(collapsed)"

        let bodyChanged = context.coordinator.loadedBodyKey != bodyKey
        if bodyChanged {
            context.coordinator.loadedBodyKey = bodyKey
            context.coordinator.appliedHighlightKey = nil
            context.coordinator.pendingHighlightOverlayKey = nil
            context.coordinator.highlightOverlayGeneration += 1
            _selectionActive.wrappedValue = false
            context.coordinator.lastSelectionPayload = nil
            context.coordinator.consumedHighlightApplyToken = highlightApplyToken

            let fullHTML = Self.wrapDocument(body: sourceHTML, collapsed: collapsed)
            webView.loadHTMLString(fullHTML, baseURL: nil)
        } else if context.coordinator.appliedHighlightKey != highlightKey,
                  context.coordinator.pendingHighlightOverlayKey != highlightKey,
                  !webView.isLoading {
            context.coordinator.applyHighlightOverlay(webView: webView, highlightKey: highlightKey)
        }

        if highlightApplyToken != context.coordinator.consumedHighlightApplyToken {
            context.coordinator.consumedHighlightApplyToken = highlightApplyToken
            context.coordinator.applyCachedHighlightIfPossible()
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "phathomSelection")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "phathomHighlightTap")
        coordinator.webView = nil
        coordinator.lastSelectionPayload = nil
        coordinator.highlightOverlayGeneration += 1
    }

    static func disableScrolling(in webView: WKWebView) {
        if let scrollView = webView.enclosingScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
            scrollView.drawsBackground = false
            return
        }
        for subview in webView.subviews {
            guard let scrollView = subview as? NSScrollView else { continue }
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
            scrollView.drawsBackground = false
        }
    }

    private static func stableFingerprint(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func wrapDocument(body: String, collapsed: Bool) -> String {
        let collapsedClass = collapsed ? " phathom-source-collapsed" : ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(HighlightableMarkdownWebViewScript.css)
        </style>
        </head>
        <body class="phathom-source\(collapsedClass)">
        \(body)
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var selectionActive: Binding<Bool>
        var highlightApplyTokenBinding: Binding<Int>

        var collapsed: Bool = false
        var highlights: [Highlight]
        var onCreateHighlight: (String, Int?) -> Void
        var onTapHighlight: (Highlight) -> Void

        weak var webView: WKWebView?
        /// Fingerprint for wrapped HTML body + collapsed flag; reload WKWebView only when this changes.
        var loadedBodyKey: String?
        /// Matches `highlightKey` last applied in JS (inject path or `didFinish`).
        var appliedHighlightKey: String?
        /// Prevents duplicate `evaluateJavaScript` while an overlay is still committing.
        var pendingHighlightOverlayKey: String?
        /// Invalidates stale `evaluateJavaScript` completions when a newer overlay starts (or body reloads).
        var highlightOverlayGeneration: Int = 0
        var consumedHighlightApplyToken: Int = 0
        var lastSelectionPayload: SelectionPayload?

        init(
            selectionActive: Binding<Bool>,
            highlightApplyToken: Binding<Int>,
            highlights: [Highlight],
            onCreateHighlight: @escaping (String, Int?) -> Void,
            onTapHighlight: @escaping (Highlight) -> Void
        ) {
            self.selectionActive = selectionActive
            self.highlightApplyTokenBinding = highlightApplyToken
            self.highlights = highlights
            self.onCreateHighlight = onCreateHighlight
            self.onTapHighlight = onTapHighlight
        }

        static func highlightKey(for highlights: [Highlight]) -> String {
            highlights.map { "\($0.id.uuidString)-\($0.sourceMarkdownOffset)-\($0.sourceMarkdownLength)" }.joined(separator: "|")
        }

        struct SelectionPayload {
            var text: String
            var hint: Int?
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "phathomSelection":
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.processSelectionMessageBody(message.body)
                }
            case "phathomHighlightTap":
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if let idString = message.body as? String,
                       let uuid = UUID(uuidString: idString),
                       let highlight = highlights.first(where: { $0.id == uuid }) {
                        onTapHighlight(highlight)
                    }
                }
            default:
                break
            }
        }

        private static let selectionActiveOnlySentinel = "active"

        private func processSelectionMessageBody(_ body: Any?) {
            if body is NSNull || body == nil {
                lastSelectionPayload = nil
                selectionActive.wrappedValue = false
                return
            }
            if let raw = body as? String, raw == Self.selectionActiveOnlySentinel {
                lastSelectionPayload = nil
                selectionActive.wrappedValue = true
                return
            }
            guard let payload = Self.parseSelectionPayloadBody(body) else {
                lastSelectionPayload = nil
                selectionActive.wrappedValue = true
                return
            }
            lastSelectionPayload = payload
            selectionActive.wrappedValue = true
        }

        /// Reads live DOM selection when the user commits Highlight (selection may have cleared from cache).
        func commitHighlightFromLiveSelection(fallback: SelectionPayload? = nil) {
            guard let webView else {
                if let fallback { deliverHighlightPayload(fallback) }
                return
            }
            webView.evaluateJavaScript("phathomSelectionPayload()") { [weak self] body, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let payload = Self.parseSelectionPayloadBody(body) {
                        self.deliverHighlightPayload(payload)
                    } else if let fallback {
                        self.deliverHighlightPayload(fallback)
                    }
                }
            }
        }

        private func deliverHighlightPayload(_ payload: SelectionPayload) {
            guard !payload.text.isEmpty else { return }
            onCreateHighlight(payload.text, payload.hint)
        }

        static func parseSelectionPayloadBody(_ body: Any?) -> SelectionPayload? {
            if body is NSNull || body == nil { return nil }
            guard let raw = body as? String,
                  let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            let hint = intValue(json["hint"])
            return SelectionPayload(text: text, hint: hint)
        }

        private static func intValue(_ any: Any?) -> Int? {
            switch any {
            case let i as Int: return i
            case let n as NSNumber: return n.intValue
            case let d as Double: return Int(d)
            default: return nil
            }
        }

        func applyCachedHighlightIfPossible() {
            commitHighlightFromLiveSelection(fallback: lastSelectionPayload)
        }

        func applyHighlightOverlay(webView: WKWebView, highlightKey: String) {
            highlightOverlayGeneration += 1
            let generation = highlightOverlayGeneration
            pendingHighlightOverlayKey = highlightKey
            let ranges: [[String: Any]] = highlights.map { highlight in
                var entry: [String: Any] = [
                    "start": highlight.sourceMarkdownOffset,
                    "end": highlight.sourceMarkdownOffset + highlight.sourceMarkdownLength,
                    "id": highlight.id.uuidString,
                ]
                if let segmentsJSON = highlight.sourceMarkdownSegmentsJSON,
                   let data = segmentsJSON.data(using: .utf8),
                   let segments = try? JSONSerialization.jsonObject(with: data) {
                    entry["segments"] = segments
                }
                return entry
            }
            guard let data = try? JSONSerialization.data(withJSONObject: ranges),
                  let json = String(data: data, encoding: .utf8)
            else {
                if generation == highlightOverlayGeneration {
                    appliedHighlightKey = highlightKey
                    pendingHighlightOverlayKey = nil
                }
                scheduleRemeasure(webView: webView)
                return
            }
            let js = "phathomClearHighlights(); phathomApplyHighlights(\(json));"
            webView.evaluateJavaScript(js) { [weak self] _, _ in
                guard let self else { return }
                guard generation == self.highlightOverlayGeneration else { return }
                self.appliedHighlightKey = highlightKey
                self.pendingHighlightOverlayKey = nil
                self.scheduleRemeasure(webView: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            HighlightableMarkdownWebView.disableScrolling(in: webView)
            let key = Self.highlightKey(for: highlights)
            applyHighlightOverlay(webView: webView, highlightKey: key)
        }

        private func scheduleRemeasure(webView: WKWebView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.remeasureContent(webView: webView)
            }
        }

        /// Collapsed: `clientHeight` respects `max-height` on `body`. Expanded: full document scroll height.
        private func remeasureContent(webView: WKWebView) {
            guard let w = webView as? IntrinsicHeightWebView else { return }
            let js: String
            if collapsed {
                js = """
                (function() {
                  var b = document.body;
                  return Math.ceil(Math.max(b ? b.clientHeight : 0, 1));
                })();
                """
            } else {
                js = """
                (function() {
                  var b = document.body;
                  var e = document.documentElement;
                  return Math.ceil(Math.max(
                    b ? b.scrollHeight : 0,
                    b ? b.offsetHeight : 0,
                    e ? e.scrollHeight : 0,
                    1
                  ));
                })();
                """
            }
            webView.evaluateJavaScript(js) { result, _ in
                let height: CGFloat? = {
                    if let x = result as? CGFloat { return x }
                    if let x = result as? Double { return CGFloat(x) }
                    if let x = result as? NSNumber { return CGFloat(truncating: x) }
                    return nil
                }()
                guard let height else { return }
                DispatchQueue.main.async {
                    w.applyMeasuredHeight(height)
                }
            }
        }
    }
}
#endif
