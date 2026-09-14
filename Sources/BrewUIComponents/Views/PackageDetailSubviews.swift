/*
 * [INPUT]: 依赖 SwiftUI 本地化文本与共享主题
 * [OUTPUT]: 对外提供 包详情的节标题与分隔线
 * [POS]: 详情表面共享结构；标题资源在当前语言的展示边界解析
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  PackageDetailSubviews.swift
//  BrewUIComponents
//

import SwiftUI

/// Section heading used across package-detail surfaces.
public struct PackageDetailSectionHeading: View {
    @Environment(\.brewLocalization) private var localization

    let title: String.LocalizationValue

    public init(title: String.LocalizationValue) {
        self.title = title
    }

    public var body: some View {
        Text(localization.string(title))
            .font(.brewSubheadline.weight(.semibold))
            .foregroundStyle(Color.brewTextPrimary)
    }
}

/// Hairline divider between package-detail sections.
public struct PackageDetailSectionDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .overlay(Color.brewBorderSeparator)
    }
}
