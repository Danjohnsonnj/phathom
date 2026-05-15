import PhathomCore
import SwiftUI
import WebKit

/// WKWebView reports `.zero` intrinsic size; SwiftUI would otherwise give it no height.
private final class IntrinsicHeightWebView: WKWebView {
    private var measuredHeight: CGFloat = 120

    /// Fired when user chooses **Highlight** from `buildMenu` injection (WebKit selection menu) if iOS includes that path.
    var onHighlightMenuAction: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight)
    }

    func applyMeasuredHeight(_ height: CGFloat) {
        let clamped = max(44, height)
        guard abs(clamped - measuredHeight) > 0.5 else { return }
        measuredHeight = clamped
        invalidateIntrinsicContentSize()
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        let action = UIAction(title: "Highlight", image: UIImage(systemName: "highlighter")) { [weak self] _ in
            self?.onHighlightMenuAction?()
        }
        let highlightMenu = UIMenu(options: .displayInline, children: [action])
        if builder.menu(for: .standardEdit) != nil {
            builder.insertChild(highlightMenu, atEndOfMenu: .standardEdit)
        }
    }
}

struct HighlightableMarkdownWebView: UIViewRepresentable {
    @Binding var selectionActive: Bool
    @Binding var highlightApplyToken: Int

    var sourceHTML: String
    var highlights: [Highlight]
    var collapsed: Bool
    var onCreateHighlight: (Int, Int, String) -> Void
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

    func makeUIView(context: Context) -> WKWebView {
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
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        let coord = context.coordinator
        webView.onHighlightMenuAction = { [weak coord] in
            coord?.applyCachedHighlightIfPossible()
        }

        let editMenu = UIEditMenuInteraction(delegate: context.coordinator)
        webView.addInteraction(editMenu)
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.selectionActive = $selectionActive
        context.coordinator.highlightApplyTokenBinding = $highlightApplyToken
        context.coordinator.collapsed = collapsed
        context.coordinator.highlights = highlights
        context.coordinator.onCreateHighlight = onCreateHighlight
        context.coordinator.onTapHighlight = onTapHighlight

        let highlightKey = Coordinator.highlightKey(for: highlights)
        let bodyKey = "\(sourceHTML.hashValue)_\(collapsed)"

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIEditMenuInteractionDelegate {
        var selectionActive: Binding<Bool>
        var highlightApplyTokenBinding: Binding<Int>

        var collapsed: Bool = false
        var highlights: [Highlight]
        var onCreateHighlight: (Int, Int, String) -> Void
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
            onCreateHighlight: @escaping (Int, Int, String) -> Void,
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
            var start: Int
            var end: Int
            var text: String
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

        private func processSelectionMessageBody(_ body: Any?) {
            if body is NSNull || body == nil {
                lastSelectionPayload = nil
                selectionActive.wrappedValue = false
                return
            }
            guard let raw = body as? String,
                  let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                lastSelectionPayload = nil
                selectionActive.wrappedValue = false
                return
            }
            guard let start = Self.intValue(json["start"]),
                  let end = Self.intValue(json["end"]),
                  end > start,
                  let text = json["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                lastSelectionPayload = nil
                selectionActive.wrappedValue = false
                return
            }
            lastSelectionPayload = SelectionPayload(start: start, end: end, text: text)
            selectionActive.wrappedValue = true
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
            guard let p = lastSelectionPayload, !p.text.isEmpty, p.end > p.start else { return }
            let length = p.end - p.start
            onCreateHighlight(p.start, length, p.text)
        }

        func applyHighlightOverlay(webView: WKWebView, highlightKey: String) {
            highlightOverlayGeneration += 1
            let generation = highlightOverlayGeneration
            pendingHighlightOverlayKey = highlightKey
            let ranges: [[String: Any]] = highlights.map {
                ["start": $0.sourceMarkdownOffset, "end": $0.sourceMarkdownOffset + $0.sourceMarkdownLength, "id": $0.id.uuidString]
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

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            var children = suggestedActions
            if let payload = lastSelectionPayload, !payload.text.isEmpty {
                let captured = payload
                let action = UIAction(title: "Highlight") { [weak self] _ in
                    let length = captured.end - captured.start
                    self?.onCreateHighlight(captured.start, length, captured.text)
                }
                children.append(action)
            }
            return UIMenu(children: children)
        }
    }
}

private enum HighlightableMarkdownWebViewScript {
    static let javaScript: String = """
    function phathomExpandSpanHits(initial) {
      if (initial.length === 0) return initial;
      let start = Infinity;
      let end = -1;
      for (const el of initial) {
        const s = parseInt(el.getAttribute('data-md-start'), 10);
        const e = parseInt(el.getAttribute('data-md-end'), 10);
        if (Number.isNaN(s) || Number.isNaN(e)) continue;
        start = Math.min(start, s);
        end = Math.max(end, e);
      }
      if (start === Infinity || end <= start) return initial;
      const expanded = Array.from(document.querySelectorAll('[data-md-start]')).filter((el) => {
        const s = parseInt(el.getAttribute('data-md-start'), 10);
        const e = parseInt(el.getAttribute('data-md-end'), 10);
        return !Number.isNaN(s) && !Number.isNaN(e) && s < end && e > start;
      });
      expanded.sort((a, b) => {
        return parseInt(a.getAttribute('data-md-start'), 10) - parseInt(b.getAttribute('data-md-start'), 10);
      });
      return expanded;
    }

    function phathomCollectSpansInRange(range) {
      const root = range.commonAncestorContainer.nodeType === 1
        ? range.commonAncestorContainer
        : range.commonAncestorContainer.parentElement;
      if (!root) return [];
      const hits = [];
      // querySelectorAll returns descendants only; common ancestor may be a leaf [data-md-start] span.
      if (root.nodeType === 1 && root.hasAttribute && root.hasAttribute('data-md-start')) {
        try {
          if (range.intersectsNode(root)) hits.push(root);
        } catch (_) {}
      }
      const all = root.querySelectorAll ? Array.from(root.querySelectorAll('[data-md-start]')) : [];
      for (const el of all) {
        try {
          if (range.intersectsNode(el)) hits.push(el);
        } catch (_) {}
      }
      return phathomExpandSpanHits(hits);
    }

    function phathomSelectionPayload() {
      const sel = window.getSelection();
      if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return null;
      const range = sel.getRangeAt(0);
      const nodes = phathomCollectSpansInRange(range);
      if (nodes.length === 0) return null;
      let start = Infinity;
      let end = -1;
      for (const el of nodes) {
        const s = parseInt(el.getAttribute('data-md-start'), 10);
        const e = parseInt(el.getAttribute('data-md-end'), 10);
        if (Number.isNaN(s) || Number.isNaN(e)) continue;
        start = Math.min(start, s);
        end = Math.max(end, e);
      }
      if (start === Infinity || end <= start) return null;
      return JSON.stringify({
        start: start,
        end: end,
        text: sel.toString()
      });
    }

    function phathomWrapMarkdownRange(start, end, id) {
      const spans = Array.from(document.querySelectorAll('[data-md-start]'))
        .filter((el) => {
          const s = parseInt(el.getAttribute('data-md-start'), 10);
          const e = parseInt(el.getAttribute('data-md-end'), 10);
          return !Number.isNaN(s) && !Number.isNaN(e) && s < end && e > start;
        })
        .sort((a, b) => parseInt(a.getAttribute('data-md-start'), 10) - parseInt(b.getAttribute('data-md-start'), 10));
      if (spans.length === 0) return;

      const blockSelector = 'p, li, h1, h2, h3, h4, blockquote, td, pre';
      let i = 0;
      while (i < spans.length) {
        const block = spans[i].closest(blockSelector);
        let j = i + 1;
        while (j < spans.length && spans[j].closest(blockSelector) === block) j += 1;
        const group = spans.slice(i, j);
        const mark = document.createElement('mark');
        mark.className = 'phathom-highlight';
        mark.dataset.highlightId = id;
        const parent = group[0].parentNode;
        if (!parent) { i = j; continue; }
        parent.insertBefore(mark, group[0]);
        for (const node of group) mark.appendChild(node);
        i = j;
      }
    }

    function phathomApplyHighlights(ranges) {
      for (const r of ranges) {
        phathomWrapMarkdownRange(r.start, r.end, r.id);
      }
    }

    function phathomClearHighlights() {
      document.querySelectorAll('mark.phathom-highlight').forEach((mark) => {
        const parent = mark.parentNode;
        if (!parent) return;
        while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
        parent.removeChild(mark);
      });
    }

    document.addEventListener('selectionchange', () => {
      try {
        const payload = phathomSelectionPayload();
        window.webkit.messageHandlers.phathomSelection.postMessage(payload);
      } catch (_) {}
    });

    document.addEventListener('click', (ev) => {
      const mark = ev.target.closest && ev.target.closest('mark.phathom-highlight');
      if (!mark) return;
      const id = mark.dataset.highlightId;
      if (id) {
        window.webkit.messageHandlers.phathomHighlightTap.postMessage(id);
      }
    });
    """

    static let css: String = """
    :root {
      --text-primary: #fffcf2;
      --text-secondary: #ccc5b9;
      --text-tertiary: rgba(204, 197, 185, 0.72);
      --accent: #eb5e28;
      --surface-nested: #353330;
      --bg: #252422;
    }
    body.phathom-source {
      font: -apple-system-body;
      font-size: 16px;
      line-height: 1.5;
      color: var(--text-primary);
      background: var(--bg);
      margin: 0;
      padding: 0;
      -webkit-text-size-adjust: 100%;
    }
    body.phathom-source-collapsed {
      max-height: 12em;
      overflow: hidden;
    }
    h1, h2 {
      font-weight: 600;
      border-bottom: 1px solid var(--text-tertiary);
      padding-bottom: 0.3em;
      margin: 1em 0 0.75em;
    }
    h1:first-child, h2:first-child { margin-top: 0; }
    h1 { font-size: 1.75em; }
    h2 { font-size: 1.4em; }
    h3, h4, h5, h6 { font-weight: 600; margin: 0.75em 0 0.5em; }
    p { margin: 0 0 1em; }
    a { color: var(--accent); text-decoration: none; }
    blockquote {
      border-left: 0.2em solid var(--text-tertiary);
      margin: 0 0 1em;
      padding-left: 1em;
      color: var(--text-secondary);
    }
    pre, code {
      font-family: ui-monospace, monospace;
      font-size: 0.85em;
    }
    pre {
      background: var(--surface-nested);
      border-radius: 6px;
      padding: 12px;
      overflow-x: auto;
      margin: 0 0 1em;
    }
    code { background: rgba(53, 51, 48, 0.55); padding: 0.1em 0.25em; border-radius: 4px; }
    pre code { background: none; padding: 0; }
    ul, ol { padding-left: 1.25em; margin: 0 0 1em; }
    li { margin-bottom: 0.25em; }
    table { border-collapse: collapse; margin: 0 0 1em; width: 100%; }
    th, td { border: 1px solid var(--text-tertiary); padding: 0.5em; text-align: left; }
    th { background: var(--surface-nested); }
    hr { border: none; border-top: 1px solid var(--text-tertiary); margin: 1em 0; }
    img { max-width: 100%; height: auto; }
    mark.phathom-highlight {
      background: rgba(235, 94, 40, 0.35);
      border-radius: 2px;
      color: inherit;
    }
    """
}
