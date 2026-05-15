import PhathomCore
import SwiftUI
import UIKit

/// Renders stripped plain text with highlight spans. **`highlights` must be sorted by `plainTextOffset`** (e.g. `ContentItem.highlightsSortedByPlainTextOffset`).
struct HighlightableSourceTextView: UIViewRepresentable {
    var plainText: String
    var highlights: [Highlight]
    var onCreateHighlight: (NSRange, String) -> Void
    var onTapHighlight: (Highlight) -> Void
    var onResizeHighlight: (Highlight, NSRange, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> HighlightTextView {
        let tv = HighlightTextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.adjustsFontForContentSizeCategory = true
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.textColor = UIColor.label
        tv.linkTextAttributes = [:]

        let coord = context.coordinator
        tv.onHighlightMenuAction = { [weak coord] range, fragment in
            coord?.parent.onCreateHighlight(range, fragment)
        }

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.longPressed(_:))
        )
        longPress.minimumPressDuration = 0.45
        tv.addGestureRecognizer(longPress)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        tv.addGestureRecognizer(tap)

        return tv
    }

    func updateUIView(_ uiView: HighlightTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateContentFingerprintIfNeeded(plainText: plainText, highlights: highlights)
        let raw = uiView.textContainer.size.width > 1 ? uiView.textContainer.size.width : uiView.bounds.width
        let w = max(1, raw > 1 ? raw : 320)
        context.coordinator.applyLayoutIfNeeded(
            uiView: uiView,
            plainText: plainText,
            highlights: highlights,
            containerWidth: CGFloat(w)
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: HighlightTextView, context: Context) -> CGSize? {
        context.coordinator.parent = self
        context.coordinator.updateContentFingerprintIfNeeded(plainText: plainText, highlights: highlights)
        let w = max(1, proposal.width ?? 320)
        context.coordinator.applyLayoutIfNeeded(
            uiView: uiView,
            plainText: plainText,
            highlights: highlights,
            containerWidth: w
        )
        let h = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: w, height: max(1, h))
    }

    static func dismantleUIView(_ uiView: HighlightTextView, coordinator: Coordinator) {
        coordinator.cancelResizeWorkForTeardown()
    }

    private static func applyContent(
        to uiView: HighlightTextView,
        plainText: String,
        highlights: [Highlight],
        containerWidth: CGFloat
    ) {
        let w = max(1, containerWidth - uiView.textContainerInset.left - uiView.textContainerInset.right)
        uiView.textContainer.size = CGSize(width: w, height: .greatestFiniteMagnitude)
        uiView.attributedText = buildAttributedString(
            plainText: plainText,
            highlights: highlights,
            traitCollection: uiView.traitCollection
        )
        uiView.invalidateIntrinsicContentSize()
    }

    private static func buildAttributedString(
        plainText: String,
        highlights: [Highlight],
        traitCollection: UITraitCollection
    ) -> NSAttributedString {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor.label
        let mas = NSMutableAttributedString(
            string: plainText,
            attributes: [
                .font: baseFont,
                .foregroundColor: baseColor,
            ]
        )
        let fullLen = (plainText as NSString).length
        let (hiBg, hiFg) = highlightSpanColors(traitCollection: traitCollection)
        for h in highlights {
            let start = h.plainTextOffset
            let len = h.plainTextLength
            guard start >= 0, start < fullLen, len > 0 else { continue }
            let end = min(start + len, fullLen)
            let runLen = end - start
            guard runLen > 0 else { continue }
            let r = NSRange(location: start, length: runLen)
            mas.addAttributes(
                [
                    .backgroundColor: hiBg,
                    .foregroundColor: hiFg,
                ],
                range: r
            )
        }
        return mas
    }

    /// Higher contrast when Increase Contrast is on; keeps orange family for brand continuity.
    private static func highlightSpanColors(traitCollection: UITraitCollection) -> (UIColor, UIColor) {
        if traitCollection.accessibilityContrast == .high {
            let bg = UIColor.systemOrange
            let fg = UIColor.black
            return (bg, fg)
        }
        let bg = UIColor(red: 235 / 255, green: 94 / 255, blue: 40 / 255, alpha: 1)
        let fg = UIColor.white
        return (bg, fg)
    }

    private func highlight(containingUTF16Index idx: Int) -> Highlight? {
        let full = (plainText as NSString).length
        for h in highlights {
            let start = max(0, min(h.plainTextOffset, full))
            let end = max(start, min(h.plainTextOffset + h.plainTextLength, full))
            if idx >= start && idx < end { return h }
        }
        return nil
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightableSourceTextView
        var resizeSession: (highlight: Highlight, initial: NSRange)?
        var debounceTask: Task<Void, Never>?

        private var contentFingerprint: String = ""
        var appliedLayoutSignature: String = ""
        /// Bumped when `plainText` / highlight set changes; debounced resize commits ignore stale epochs.
        private(set) var contentEpoch: UInt64 = 0

        init(parent: HighlightableSourceTextView) {
            self.parent = parent
        }

        func cancelResizeWorkForTeardown() {
            debounceTask?.cancel()
            debounceTask = nil
            resizeSession = nil
            contentEpoch &+= 1
        }

        func updateContentFingerprintIfNeeded(plainText: String, highlights: [Highlight]) {
            let fp = Self.makeContentFingerprint(plainText: plainText, highlights: highlights)
            guard fp != contentFingerprint else { return }
            contentFingerprint = fp
            contentEpoch &+= 1
            debounceTask?.cancel()
            debounceTask = nil
            resizeSession = nil
        }

        func applyLayoutIfNeeded(
            uiView: HighlightTextView,
            plainText: String,
            highlights: [Highlight],
            containerWidth: CGFloat
        ) {
            let sig = Self.makeLayoutSignature(plainText: plainText, highlights: highlights, width: containerWidth)
            guard sig != appliedLayoutSignature else { return }
            appliedLayoutSignature = sig
            HighlightableSourceTextView.applyContent(
                to: uiView,
                plainText: plainText,
                highlights: highlights,
                containerWidth: containerWidth
            )
        }

        private static func makeContentFingerprint(plainText: String, highlights: [Highlight]) -> String {
            let ids = highlights.map { h in
                "\(h.id.uuidString)|\(h.plainTextOffset)|\(h.plainTextLength)|\(h.quotedText.count)"
            }.joined(separator: ";")
            return "\(plainText.utf8.count)|\(ids)"
        }

        private static func makeLayoutSignature(plainText: String, highlights: [Highlight], width: CGFloat) -> String {
            "\(makeContentFingerprint(plainText: plainText, highlights: highlights))|\(Int((width * 1_000).rounded()))"
        }

        func textViewShouldBeginEditing(_ textView: UITextView) -> Bool { false }

        @objc func longPressed(_ gr: UILongPressGestureRecognizer) {
            switch gr.state {
            case .began:
                guard let tv = gr.view as? HighlightTextView else { return }
                let pt = gr.location(in: tv)
                guard let idx = characterIndex(in: tv, at: pt),
                      let h = parent.highlight(containingUTF16Index: idx)
                else { return }
                let full = (parent.plainText as NSString).length
                let start = max(0, min(h.plainTextOffset, full))
                let end = max(start, min(h.plainTextOffset + h.plainTextLength, full))
                let r = NSRange(location: start, length: end - start)
                guard r.length > 0 else { return }
                resizeSession = (h, r)
                tv.selectedRange = r
            case .cancelled, .failed:
                debounceTask?.cancel()
                debounceTask = nil
                resizeSession = nil
            default:
                break
            }
        }

        @objc func tapped(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended, let tv = gr.view as? HighlightTextView else { return }
            if tv.selectedRange.length > 0 { return }
            let pt = gr.location(in: tv)
            guard let idx = characterIndex(in: tv, at: pt),
                  let h = parent.highlight(containingUTF16Index: idx)
            else { return }
            parent.onTapHighlight(h)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            debounceTask?.cancel()
            guard let session = resizeSession else { return }
            let r = textView.selectedRange
            if r.length == 0 {
                resizeSession = nil
                return
            }
            let captured = r
            let epochAtSchedule = contentEpoch
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled else { return }
                guard epochAtSchedule == self.contentEpoch else { return }
                guard textView.selectedRange == captured, captured.length > 0 else { return }
                let fragment = (textView.text as NSString).substring(with: captured)
                if captured != session.initial {
                    parent.onResizeHighlight(session.highlight, captured, fragment)
                }
                resizeSession = nil
            }
        }

        private func characterIndex(in tv: UITextView, at point: CGPoint) -> Int? {
            let layoutManager = tv.layoutManager
            let container = tv.textContainer
            var fraction: CGFloat = 0
            let glyphIndex = layoutManager.glyphIndex(for: point, in: container, fractionOfDistanceThroughGlyph: &fraction)
            return layoutManager.characterIndexForGlyph(at: glyphIndex)
        }
    }
}

final class HighlightTextView: UITextView {
    var onHighlightMenuAction: ((NSRange, String) -> Void)?

    override var intrinsicContentSize: CGSize {
        let w = textContainer.size.width
        let h = sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: UIView.noIntrinsicMetric, height: h)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let coordinator = delegate as? HighlightableSourceTextView.Coordinator else { return }
        coordinator.appliedLayoutSignature = ""
    }

    @available(iOS 17.0, *)
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        var children = suggestedActions
        if selectedRange.length > 0 {
            let highlightAction = UIAction(
                title: "Highlight",
                image: UIImage(systemName: "highlighter")
            ) { [weak self] _ in
                guard let self else { return }
                let r = self.selectedRange
                guard r.length > 0,
                      let swift = Range(r, in: self.text)
                else { return }
                let fragment = String(self.text[swift])
                self.onHighlightMenuAction?(r, fragment)
            }
            children.append(highlightAction)
        }
        return UIMenu(children: children)
    }
}
