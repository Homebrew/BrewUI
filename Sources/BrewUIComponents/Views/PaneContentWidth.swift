//
//  PaneContentWidth.swift
//  BrewUIComponents
//

import SwiftUI

public extension View {
    /// 正文保留原生列表缩进，再补半格以对齐窗口标题的左边缘。
    /// 只增加前缘间距，不移动分栏边界和右侧滚动条。
    func brewAlignWithWindowTitle() -> some View {
        padding(.leading, BrewSpacing.xs)
    }

    /// The outer frame keeps the enclosing scroll view full-width, so its scroller stays at the pane's
    /// trailing edge rather than stopping where the content does.
    func brewPaneContentWidth() -> some View {
        frame(maxWidth: BrewLayout.paneContentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
