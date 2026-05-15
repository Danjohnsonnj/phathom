#if DEBUG
import Foundation

/// Shared WK user script for source-content spike (`docs/handoff/real-markdown-highlights-spike.md`).
enum SourceContentSpikeScript {
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

    function phathomPayloadFromSpan(el) {
      const s = parseInt(el.getAttribute('data-md-start'), 10);
      const e = parseInt(el.getAttribute('data-md-end'), 10);
      if (Number.isNaN(s) || Number.isNaN(e) || e <= s) return null;
      return JSON.stringify({
        start: s,
        end: e,
        text: (el.textContent || '').trim()
      });
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

    function phathomSelectSpan(startAttr, endAttr) {
      const el = document.querySelector('[data-md-start="' + startAttr + '"][data-md-end="' + endAttr + '"]');
      if (!el) return null;
      try {
        const range = document.createRange();
        range.selectNodeContents(el);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      } catch (_) {}
      // WK often returns null from getSelection right after programmatic select (especially inside <mark>).
      return phathomSelectionPayload() || phathomPayloadFromSpan(el);
    }

    function phathomSelectAcrossSpans(startA, endA, startB, endB) {
      const sA = parseInt(startA, 10);
      const eA = parseInt(endA, 10);
      const sB = parseInt(startB, 10);
      const eB = parseInt(endB, 10);
      const lo = Math.min(sA, sB);
      const hi = Math.max(eA, eB);
      const spans = Array.from(document.querySelectorAll('[data-md-start]'))
        .filter((el) => {
          const s = parseInt(el.getAttribute('data-md-start'), 10);
          const e = parseInt(el.getAttribute('data-md-end'), 10);
          return !Number.isNaN(s) && !Number.isNaN(e) && s < hi && e > lo;
        })
        .sort((a, b) => parseInt(a.getAttribute('data-md-start'), 10) - parseInt(b.getAttribute('data-md-start'), 10));
      if (spans.length === 0) return null;

      const first = spans[0];
      const last = spans[spans.length - 1];
      const range = document.createRange();
      const firstNode = first.firstChild || first;
      const lastNode = last.firstChild || last;
      range.setStart(firstNode, 0);
      range.setEnd(lastNode, lastNode.textContent ? lastNode.textContent.length : 0);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
      return phathomSelectionPayload();
    }

    function phathomClearHighlights() {
      document.querySelectorAll('mark.phathom-highlight').forEach((mark) => {
        const parent = mark.parentNode;
        if (!parent) return;
        while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
        parent.removeChild(mark);
      });
    }

    function phathomSpikeSelfTest(expectationsInput) {
      const expectations = typeof expectationsInput === 'string'
        ? JSON.parse(expectationsInput)
        : expectationsInput;
      if (!Array.isArray(expectations)) {
        return [{ name: 'expectations_shape', pass: false, detail: 'expected array' }];
      }
      phathomClearHighlights();

      const results = [];
      function assert(name, pass, detail) {
        results.push({ name: name, pass: !!pass, detail: detail || '' });
      }

      for (const ex of expectations) {
        let raw = null;
        if (ex.kind === 'single') {
          raw = phathomSelectSpan(String(ex.start), String(ex.end));
        } else if (ex.kind === 'across') {
          raw = phathomSelectAcrossSpans(
            String(ex.startA), String(ex.endA), String(ex.startB), String(ex.endB)
          );
        }
        if (!raw) {
          assert(ex.name, false, 'no payload');
          continue;
        }
        const p = JSON.parse(raw);
        const okStart = Number(p.start) === Number(ex.wantStart);
        const okEnd = Number(p.end) === Number(ex.wantEnd);
        const okText = !ex.wantText || String(p.text).trim() === String(ex.wantText).trim();
        const detail = okStart && okEnd && okText
          ? JSON.stringify(p)
          : 'got ' + JSON.stringify(p) + ' want ' + ex.wantStart + '..' + ex.wantEnd
            + (ex.wantText ? ' text=' + ex.wantText : '');
        assert(ex.name, okStart && okEnd && okText, detail);
      }

      phathomClearHighlights();
      const boldEx = expectations.find((e) => e.name === 'single_bold');
      if (boldEx) {
        phathomApplyHighlights([{
          start: boldEx.wantStart,
          end: boldEx.wantEnd,
          id: 'selftest-mark'
        }]);
      }
      const marks = document.querySelectorAll('mark.phathom-highlight');
      assert('overlay_marks_present', marks.length >= 1, 'count=' + marks.length);

      return results;
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
}
#endif
