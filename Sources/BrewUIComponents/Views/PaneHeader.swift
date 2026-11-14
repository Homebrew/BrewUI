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
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                summaryContent.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: BrewSpacing.sm)
                actions.fixedSize()
            }
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                summaryContent
                actions.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, minHeight: BrewLayout.headerActionHeight, alignment: .topLeading)
        .padding(BrewSpacing.lg)
        .accessibilityElement(children: .contain)
        .axid(.paneHeader)
    }

    private var summaryContent: some View {
        summary
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .axid(.paneHeaderSummary)
    }
}

public extension PaneHeader where Actions == EmptyView {
    init(@ViewBuilder summary: () -> Summary) {
        self.init(summary: summary, actions: { EmptyView() })
    }
}
