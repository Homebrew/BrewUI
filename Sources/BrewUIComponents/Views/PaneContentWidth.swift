//
//  PaneContentWidth.swift
//  BrewUIComponents
//

import SwiftUI

public extension View {
    /// 原生 inset 列表自带 16pt 留白，只在行内容内补齐到共用边距。
    /// 分隔线跟随内容边缘；列表背景、滚动条和垂直间距不变。
    func brewPaneListRowInsets() -> some View {
        listRowInsets(.horizontal, BrewLayout.paneContentInset - BrewSpacing.lg)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
    }

    /// 正文列表的选中底色两侧各留 10pt，不改变行内容和分隔线。
    func brewPaneListRowSelection(isSelected: Bool) -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: BrewRadius.lg, style: .continuous)
                .fill(isSelected ? Color.brewBrandTint : Color.clear)
                .padding(.horizontal, BrewSpacing.sm + BrewSpacing.xxs),
        )
    }

    /// The outer frame keeps the enclosing scroll view full-width, so its scroller stays at the pane's
    /// trailing edge rather than stopping where the content does.
    /// Configuration supplies a wider limit; other panes use the shared default.
    func brewPaneContentWidth(maxWidth: CGFloat = BrewLayout.paneContentMaxWidth) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
