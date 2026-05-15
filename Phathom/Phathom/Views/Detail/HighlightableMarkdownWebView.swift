import PhathomCore
import SwiftUI
import WebKit

struct HighlightableMarkdownWebView: UIViewRepresentable {
    var sourceHTML: String
    var highlights: [Highlight]
    var collapsed: Bool
    var onCreateHighlight: (Int, Int, String) -> Void
    var onTapHighlight: (Highlight) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
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

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        let editMenu = UIEditMenuInteraction(delegate: context.coordinator)
        webView.addInteraction(editMenu)
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.highlights = highlights
        context.coordinator.onCreateHighlight = onCreateHighlight
        context.coordinator.onTapHighlight = onTapHighlight

        let highlightKey = highlights.map { "\($0.id.uuidString)-\($0.sourceMarkdownOffset)-\($0.sourceMarkdownLength)" }.joined()
        let fingerprint = sourceHTML.hashValue ^ collapsed.hashValue ^ highlightKey.hashValue

        guard context.coordinator.loadedFingerprint != fingerprint else { return }
        context.coordinator.loadedFingerprint = fingerprint
        context.coordinator.pendingHighlights = highlights.map {
            (start: $0.sourceMarkdownOffset, end: $0.sourceMarkdownOffset + $0.sourceMarkdownLength, id: $0.id.uuidString)
        }

        let fullHTML = Self.wrapDocument(body: sourceHTML, collapsed: collapsed)
        webView.loadHTMLString(fullHTML, baseURL: nil)
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
        var highlights: [Highlight]
        var onCreateHighlight: (Int, Int, String) -> Void
        var onTapHighlight: (Highlight) -> Void

        weak var webView: WKWebView?
        var loadedFingerprint: Int?
        var pendingHighlights: [(start: Int, end: Int, id: String)] = []
        private var lastSelectionPayload: SelectionPayload?

        init(
            highlights: [Highlight],
            onCreateHighlight: @escaping (Int, Int, String) -> Void,
            onTapHighlight: @escaping (Highlight) -> Void
        ) {
            self.highlights = highlights
            self.onCreateHighlight = onCreateHighlight
            self.onTapHighlight = onTapHighlight
        }

        struct SelectionPayload {
            var start: Int
            var end: Int
            var text: String
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "phathomSelection":
                if let raw = message.body as? String,
                   let data = raw.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let start = json["start"] as? Int,
                   let end = json["end"] as? Int,
                   let text = json["text"] as? String {
                    lastSelectionPayload = SelectionPayload(start: start, end: end, text: text)
                } else {
                    lastSelectionPayload = nil
                }
            case "phathomHighlightTap":
                if let idString = message.body as? String,
                   let uuid = UUID(uuidString: idString),
                   let highlight = highlights.first(where: { $0.id == uuid }) {
                    onTapHighlight(highlight)
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
            let js = "phathomClearHighlights(); phathomApplyHighlights(\(json));"
            webView.evaluateJavaScript(js)
            pendingHighlights = []
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
      const all = root.querySelectorAll ? Array.from(root.querySelectorAll('[data-md-start]')) : [];
      const hits = [];
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
