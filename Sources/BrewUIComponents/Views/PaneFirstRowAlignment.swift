import SwiftUI

private nonisolated enum PaneHeadingCentre: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        dimensions[VerticalAlignment.center]
    }
}

extension VerticalAlignment {
    nonisolated static let brewPaneHeadingCentre = VerticalAlignment(PaneHeadingCentre.self)
}

nonisolated enum PaneFirstRowTarget {
    case textCentre
    case actionTop
}

public extension View {
    /// 标记页头主标题的文字框中心；副标题和时间戳不参与首行对齐。
    func brewPaneHeadingAnchor() -> some View {
        alignmentGuide(.brewPaneHeadingCentre) { $0[VerticalAlignment.center] }
    }
}

extension View {
    func brewPaneFirstRowInset(anchor: VerticalAlignment, target: PaneFirstRowTarget) -> some View {
        PaneFirstRowInsetLayout(
            anchor: anchor,
            target: target,
            navigationTextInset: BrewSpacing.sm * 2,
            actionHeight: BrewLayout.headerActionHeight,
        ) {
            Text(verbatim: " ")
                .font(.brewBody)
                .hidden()
                .accessibilityHidden(true)
            self
        }
    }
}

private struct PaneFirstRowInsetLayout: Layout {
    let anchor: VerticalAlignment
    let target: PaneFirstRowTarget
    let navigationTextInset: CGFloat
    let actionHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let dimensions = subviews[1].dimensions(in: ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: dimensions.width, height: dimensions.height + topInset(dimensions, reference: subviews[0]))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard subviews.count == 2 else { return }
        let proposal = ProposedViewSize(width: bounds.width, height: nil)
        let dimensions = subviews[1].dimensions(in: proposal)
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + topInset(dimensions, reference: subviews[0])),
            anchor: .topLeading,
            proposal: proposal,
        )
    }

    private func topInset(_ dimensions: ViewDimensions, reference: LayoutSubview) -> CGFloat {
        let textHeight = reference.sizeThatFits(.unspecified).height
        let centre = navigationTextInset + textHeight / 2
        let targetY = target == .textCentre ? centre : centre - actionHeight / 2
        return max(0, targetY - (dimensions[explicit: anchor] ?? 0))
    }
}
