enum HighlightableMarkdownWebViewScript {
    static let javaScript: String = """
    function phathomCollectSpansInRange(range) {
      const root = range.commonAncestorContainer.nodeType === 1
        ? range.commonAncestorContainer
        : range.commonAncestorContainer.parentElement;
      if (!root) return [];
      const hits = [];
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
      const seen = new Set();
      return hits
        .sort((a, b) => parseInt(a.getAttribute('data-md-start'), 10) - parseInt(b.getAttribute('data-md-start'), 10))
        .filter((el) => {
          const key = el.getAttribute('data-md-start') + ':' + el.getAttribute('data-md-end');
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });
    }

    function phathomSelectionHintForRange(range) {
      const spans = phathomCollectSpansInRange(range);
      if (spans.length === 0) return null;
      let hint = Infinity;
      for (const span of spans) {
        const start = parseInt(span.getAttribute('data-md-start'), 10);
        if (!Number.isNaN(start)) hint = Math.min(hint, start);
      }
      return hint === Infinity ? null : hint;
    }

    function phathomSelectionPayload() {
      const sel = window.getSelection();
      if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return null;
      const range = sel.getRangeAt(0);
      const text = sel.toString();
      if (!text.trim()) return null;

      const hint = phathomSelectionHintForRange(range);
      return JSON.stringify({ text: text, hint: hint });
    }

    function phathomPostSelectionMessage() {
      const payload = phathomSelectionPayload();
      if (payload) {
        window.webkit.messageHandlers.phathomSelection.postMessage(payload);
        return;
      }
      const sel = window.getSelection();
      if (sel && sel.rangeCount > 0 && !sel.isCollapsed && sel.toString().trim()) {
        window.webkit.messageHandlers.phathomSelection.postMessage('active');
        return;
      }
      window.webkit.messageHandlers.phathomSelection.postMessage(null);
    }

    function phathomWrapMarkdownRange(start, end, id) {
      const spans = Array.from(document.querySelectorAll('[data-md-start]'))
        .filter((el) => {
          const s = parseInt(el.getAttribute('data-md-start'), 10);
          const e = parseInt(el.getAttribute('data-md-end'), 10);
          return !Number.isNaN(s) && !Number.isNaN(e) && s < end && e > start;
        });
      for (const span of spans) {
        const s = parseInt(span.getAttribute('data-md-start'), 10);
        const tn = span.firstChild;
        const mark = document.createElement('mark');
        mark.className = 'phathom-highlight';
        mark.dataset.highlightId = id;
        const wrapWholeSpan = () => {
          const parent = span.parentNode;
          if (!parent) return;
          parent.insertBefore(mark, span);
          mark.appendChild(span);
        };
        if (!tn || tn.nodeType !== Node.TEXT_NODE || span.childNodes.length !== 1) {
          wrapWholeSpan();
          continue;
        }
        const localStart = Math.max(0, start - s);
        const localEnd = Math.min(tn.length, end - s);
        if (localEnd <= localStart) continue;
        if (localStart === 0 && localEnd === tn.length) {
          wrapWholeSpan();
          continue;
        }
        const range = document.createRange();
        try {
          range.setStart(tn, localStart);
          range.setEnd(tn, localEnd);
          range.surroundContents(mark);
        } catch (_) {
          wrapWholeSpan();
        }
      }
    }

    function phathomWrapMarkdownSegments(segments, id) {
      for (const seg of segments) {
        const start = parseInt(seg.start, 10);
        const end = parseInt(seg.end, 10);
        if (Number.isNaN(start) || Number.isNaN(end) || end <= start) continue;
        phathomWrapMarkdownRange(start, end, id);
      }
    }

    function phathomApplyHighlights(ranges) {
      for (const r of ranges) {
        if (r.segments && r.segments.length > 0) {
          phathomWrapMarkdownSegments(r.segments, r.id);
        } else {
          phathomWrapMarkdownRange(r.start, r.end, r.id);
        }
      }
    }

    function phathomClearHighlights() {
      document.querySelectorAll('mark.phathom-highlight').forEach((mark) => {
        const parent = mark.parentNode;
        if (!parent) return;
        while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
        parent.removeChild(mark);
        parent.normalize();
      });
    }

    document.addEventListener('selectionchange', () => {
      try {
        phathomPostSelectionMessage();
      } catch (_) {}
    });

    document.addEventListener('contextmenu', () => {
      try {
        phathomPostSelectionMessage();
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
