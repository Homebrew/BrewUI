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
    case sidebar
    case textCentre
    case headingTop
}

public extension View {
    /// 标记页头主标题的文字框中心；副标题和时间戳不参与首行对齐。
    func brewPaneHeadingAnchor() -> some View {
        alignmentGuide(.brewPaneHeadingCentre) { $0[VerticalAlignment.center] }
    }

    /// 随正文首行一起下移侧栏，保留导航项内部留白。
    func brewSidebarFirstRowInset() -> some View {
        brewPaneFirstRowInset(anchor: .center, target: .sidebar)
    }
}

extension View {
    func brewPaneFirstRowInset(anchor: VerticalAlignment, target: PaneFirstRowTarget) -> some View {
        PaneFirstRowInsetLayout(
            anchor: anchor,
            target: target,
            navigationTextInset: BrewSpacing.sm * 2,
            actionHeight: BrewLayout.headerActionHeight,
            contentInset: BrewLayout.paneContentInset,
        ) {
            Text(verbatim: " ")
                .font(.brewBody)
                .hidden()
                .accessibilityHidden(true)
            Text(verbatim: " ")
                .font(.brewTitle2)
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
    let contentInset: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let dimensions = subviews[2].dimensions(in: ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: dimensions.width, height: dimensions.height + topInset(dimensions, navigation: subviews[0], heading: subviews[1]))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard subviews.count == 3 else { return }
        let proposal = ProposedViewSize(width: bounds.width, height: nil)
        let dimensions = subviews[2].dimensions(in: proposal)
        subviews[2].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + topInset(dimensions, navigation: subviews[0], heading: subviews[1])),
            anchor: .topLeading,
            proposal: proposal,
        )
    }

    private func topInset(_ dimensions: ViewDimensions, navigation: LayoutSubview, heading: LayoutSubview) -> CGFloat {
        let textHeight = navigation.sizeThatFits(.unspecified).height
        let centre = navigationTextInset + textHeight / 2
        let headingHeight = heading.sizeThatFits(.unspecified).height
        let rowHeight = max(actionHeight, headingHeight)
        // 以中栏首行的标准操作槽为尺，只平移既有对齐结果。
        let offset = contentInset + rowHeight / 2 - centre
        switch target {
        case .sidebar:
            return offset
        case .textCentre:
            return offset + max(0, centre - (dimensions[explicit: anchor] ?? 0))
        case .headingTop:
            return offset + max(0, centre - headingHeight / 2 - (dimensions[explicit: anchor] ?? 0))
        }
    }
}
