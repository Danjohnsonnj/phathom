import SwiftUI

/// Places subviews left-to-right, wrapping to the next row; each child keeps its ideal size.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).containerSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for index in subviews.indices {
            let origin = CGPoint(
                x: bounds.minX + result.frames[index].minX,
                y: bounds.minY + result.frames[index].minY
            )
            subviews[index].place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(result.frames[index].size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (containerSize: CGSize, frames: [CGRect]) {
        guard !subviews.isEmpty else {
            return (CGSize.zero, [])
        }

        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let subSize = subview.sizeThatFits(.unspecified)

            if x + subSize.width > maxWidth, x > 0 {
                maxLineWidth = max(maxLineWidth, x - horizontalSpacing)
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: subSize))
            lineHeight = max(lineHeight, subSize.height)
            x += subSize.width + horizontalSpacing
        }

        let lastLineWidth = max(0, x - horizontalSpacing)
        maxLineWidth = max(maxLineWidth, lastLineWidth)
        let totalHeight = y + lineHeight

        let width = min(maxLineWidth, proposal.width ?? maxLineWidth)
        return (CGSize(width: width, height: totalHeight), frames)
    }
}
