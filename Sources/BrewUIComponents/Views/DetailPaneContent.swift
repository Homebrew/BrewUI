import SwiftUI

private nonisolated enum DetailTopAnchor: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        dimensions[.top]
    }
}

private extension VerticalAlignment {
    nonisolated static let brewDetailTop = VerticalAlignment(DetailTopAnchor.self)
}

public extension View {
    /// 用 logo 或状态标签声明详情的顶部锚点，不改变其内部布局。
    func brewDetailTopAnchor() -> some View {
        alignmentGuide(.brewDetailTop) { $0[.top] }
    }

    /// 整体平移详情，使锚点对齐正文主标题的文字框顶部；横向使用共用正文边距，底部留白不变。
    /// 长文案超出顶部留白时，不用负边距裁掉文字。
    func brewDetailPaneContent() -> some View {
        brewPaneFirstRowInset(anchor: .brewDetailTop, target: .headingTop)
            .padding(.horizontal, BrewLayout.paneContentInset)
            .padding(.bottom, BrewSpacing.xl)
    }
}
