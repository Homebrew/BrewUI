/*
 * [INPUT]: 依赖 DoctorIssueItem 与当前语言环境
 * [OUTPUT]: 提供 问题行和实时辅助功能标签
 * [POS]: Doctor 列表展示，原始诊断标题与本地化操作提示分离
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  DoctorIssueRowView.swift
//  BrewFeatureDoctor
//

import BrewUIComponents
import SwiftUI

/// One `brew doctor` warning in the issues list: a severity glyph (matching the row's severity), the
/// summary, and a "fix available" hint.
struct DoctorIssueRowView: View {
    @Environment(\.brewLocalization) private var localization
    let item: DoctorIssueItem

    var body: some View {
        HStack(alignment: .center, spacing: BrewSpacing.sm) {
            DoctorSeverityStyle.glyphImage(item.severity)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text(item.title)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextPrimary)
                    .lineLimit(2)
                if item.hasRunnableFix {
                    Label("Fix available", systemImage: "wrench.and.screwdriver")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextBrand)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, BrewSpacing.xs)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel(localization: localization))
    }
}
