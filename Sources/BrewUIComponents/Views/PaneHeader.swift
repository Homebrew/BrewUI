import BrewAccessibilityID
import SwiftUI

/// 列表页共用的状态与操作布局。宽度不足时将操作移到下一行，不截断状态文字。
public struct PaneHeader<Summary: View, Actions: View>: View {
    private let summary: Summary
    private let actions: Actions

    public init(@ViewBuilder summary: () -> Summary, @ViewBuilder actions: () -> Actions) {
        self.summary = summary()
        self.actions = actions()
    }

    public var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.bottom, BrewSpacing.lg)
        .brewPaneFirstRowInset(anchor: .brewPaneHeadingCentre, target: .textCentre)
        .accessibilityElement(children: .contain)
        .axid(.paneHeader)
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

public extension PaneHeader where Actions == EmptyView {
    init(@ViewBuilder summary: () -> Summary) {
        self.init(summary: summary, actions: { EmptyView() })
    }
}
