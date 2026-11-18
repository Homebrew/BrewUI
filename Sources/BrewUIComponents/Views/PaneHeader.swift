import BrewAccessibilityID
import SwiftUI

/// 列表页共用的状态与操作布局。元数据独立成行时，主标题换行而操作保持首行。
public struct PaneHeader<Summary: View, Actions: View, Metadata: View>: View {
    private let summary: Summary
    private let actions: Actions
    private let metadata: Metadata
    private let wrapsSummary: Bool

    /// 元数据使用整行宽度，不参与主标题与操作的横向分配。
    public init(
        @ViewBuilder summary: () -> Summary,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder metadata: () -> Metadata,
    ) {
        self.summary = summary()
        self.actions = actions()
        self.metadata = metadata()
        wrapsSummary = true
    }

    public var body: some View {
        Group {
            if wrapsSummary {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    wrappingRow
                    metadata
                }
            } else {
                adaptiveRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, BrewLayout.paneContentInset)
        .padding(.bottom, BrewSpacing.lg)
        .brewPaneFirstRowInset(anchor: .brewPaneHeadingCentre, target: .textCentre)
        .accessibilityElement(children: .contain)
        .axid(.paneHeader)
    }

    private var wrappingRow: some View {
        ViewThatFits(in: .horizontal) {
            inlineRow(stacksActions: false)
            inlineRow(stacksActions: true)
            adaptiveRow
        }
    }

    private func inlineRow(stacksActions: Bool) -> some View {
        PaneHeaderInlineLayout(spacing: BrewSpacing.sm, actionHeight: BrewLayout.headerActionHeight, stacksActions: stacksActions) {
            summaryContent
            // 加载与失败状态没有按钮，仍保留布局的操作槽。
            HStack(spacing: 0) { actions.environment(\.paneHeaderStacksActions, stacksActions) }.fixedSize()
            Text(verbatim: " ")
                .font(.brewTitle2)
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private var adaptiveRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .brewPaneHeadingCentre, spacing: 0) {
                actionSlot
                summaryContent.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: BrewSpacing.sm)
                actions.fixedSize()
                    .alignmentGuide(.brewPaneHeadingCentre) { $0[VerticalAlignment.center] }
            }
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                HStack(alignment: .brewPaneHeadingCentre, spacing: 0) {
                    actionSlot
                    summaryContent.frame(maxWidth: .infinity, alignment: .leading)
                }
                actions.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var actionSlot: some View {
        Color.clear
            .frame(width: 0, height: BrewLayout.headerActionHeight)
            .alignmentGuide(.brewPaneHeadingCentre) { $0[VerticalAlignment.center] }
            .accessibilityHidden(true)
    }

    private var summaryContent: some View {
        summary
            .fixedSize(horizontal: false, vertical: true)
            .alignmentGuide(.brewPaneHeadingCentre) { dimensions in
                dimensions[explicit: .brewPaneHeadingCentre] ?? dimensions[VerticalAlignment.center]
            }
            .accessibilityElement(children: .combine)
            .axid(.paneHeaderSummary)
    }
}

public extension PaneHeader where Metadata == EmptyView {
    /// 允许标题在操作区旁换行；其他调用方可保留原有的操作换行规则。
    init(wrapsSummary: Bool = false, @ViewBuilder summary: () -> Summary, @ViewBuilder actions: () -> Actions) {
        self.summary = summary()
        self.actions = actions()
        metadata = EmptyView()
        self.wrapsSummary = wrapsSummary
    }
}

public extension PaneHeader where Actions == EmptyView, Metadata == EmptyView {
    init(@ViewBuilder summary: () -> Summary) {
        self.init(summary: summary, actions: { EmptyView() })
    }
}

/// 操作区比一行更宽时纵向排布，不缩短按钮文案。
public struct PaneHeaderActions<Content: View>: View {
    @Environment(\.paneHeaderStacksActions) private var stacksActions
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if stacksActions {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BrewSpacing.sm) { content }
                    .fixedSize(horizontal: true, vertical: false)
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .trailing, spacing: BrewSpacing.xs) {
            ForEach(subviews: content) { action in
                action.frame(minHeight: BrewLayout.headerActionHeight)
            }
        }
    }
}

private extension EnvironmentValues {
    @Entry var paneHeaderStacksActions = false
}

/// 优先为操作保留原生宽度，再让标题换行。仅在连一个标题字框都放不下时回退。
private struct PaneHeaderInlineLayout: Layout {
    let spacing: CGFloat
    let actionHeight: CGFloat
    let stacksActions: Bool

    private struct Measurement {
        let size: CGSize
        let titleWidth: CGFloat
        let lineHeight: CGFloat
        let centre: CGFloat
        let actionTop: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        measure(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let measurement = measure(width: bounds.width, subviews: subviews)
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + measurement.centre - measurement.lineHeight / 2),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: measurement.titleWidth, height: nil),
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.minY + measurement.actionTop),
            anchor: .topTrailing,
            proposal: .unspecified,
        )
        subviews[2].place(at: bounds.origin, proposal: .unspecified)
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout (),
    ) -> CGFloat? {
        guard guide == .brewPaneHeadingCentre else { return nil }
        return measure(width: bounds.width, subviews: subviews).centre
    }

    private func measure(width proposedWidth: CGFloat?, subviews: Subviews) -> Measurement {
        let actions = subviews[1].sizeThatFits(.unspecified)
        let lineHeight = subviews[2].sizeThatFits(.unspecified).height
        let gap = actions.width > 0 ? spacing : 0
        let minimumWidth = actions.width + gap + lineHeight
        // 未指定宽度时报告最小可读宽度，让 ViewThatFits 按实际宽度尝试标题换行。
        let width = max(proposedWidth ?? minimumWidth, minimumWidth)
        let titleWidth = width - actions.width - gap
        let title = subviews[0].sizeThatFits(ProposedViewSize(width: titleWidth, height: nil))
        // 纵排时对齐第一颗按钮，不对齐整组按钮的中点。
        let actionCentre = (stacksActions ? min(actionHeight, actions.height) : actions.height) / 2
        let centre = max(actionHeight / 2, lineHeight / 2, actionCentre)
        let actionTop = centre - actionCentre
        let height = max(centre * 2, centre - lineHeight / 2 + title.height, actionTop + actions.height)
        return Measurement(
            size: CGSize(width: width, height: height),
            titleWidth: titleWidth,
            lineHeight: lineHeight,
            centre: centre,
            actionTop: actionTop,
        )
    }
}
