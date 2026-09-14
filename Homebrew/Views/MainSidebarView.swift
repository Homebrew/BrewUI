/*
 * [INPUT]: 依赖 SwiftUI locale、侧栏选择 Binding 与升级徽标
 * [OUTPUT]: 展示原生本地化导航项并保留稳定的选择和无障碍身份
 * [POS]: 窗口导航展示层；语言更新不触发导航状态重置
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  MainSidebarView.swift
//  Brew
//

import BrewAccessibilityID
import BrewFeatureInstalled
import BrewUIComponents
import SwiftUI

struct MainSidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarRow(
                title: "Installed",
                emoji: "📦",
                item: .installed,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.sm)

            sidebarRow(
                title: "Upgrades",
                emoji: "⬆️",
                item: .upgrades,
                trailingAccessory: { UpgradesSidebarBadge() },
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            sidebarRow(
                title: "Discover",
                emoji: "🔍",
                item: .discover,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            sidebarRow(
                title: "Doctor",
                emoji: "🩺",
                item: .doctor,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            sidebarRow(
                title: "Configuration",
                emoji: "⚙️",
                item: .configuration,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.brewSurface)
        // `.contain` makes the sidebar itself an addressable container element without flattening
        // the rows inside it, so UI tests can scope a query to the sidebar.
        .accessibilityElement(children: .contain)
        .axid(.sidebar)
    }

    @ViewBuilder
    private func sidebarRow(
        title: LocalizedStringKey,
        emoji: String,
        item: SidebarItem,
        @ViewBuilder trailingAccessory: () -> some View = { EmptyView() },
    ) -> some View {
        let isSelected = selection == item
        Button {
            selection = item
        } label: {
            HStack(spacing: BrewSpacing.sm) {
                Text("\(emoji) \(Text(title))")
                    .font(.brewBody)
                    .foregroundStyle(isSelected ? Color.brewTextBrand : Color.brewTextPrimary)
                Spacer(minLength: 0)
                trailingAccessory()
            }
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: BrewRadius.md)
                    .fill(isSelected ? Color.brewBrandTint : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .axid(.sidebarItem(item.axDestination))
    }
}

#Preview {
    MainSidebarView(selection: .constant(.installed))
        .frame(width: BrewLayout.sidebarWidth, height: 400)
}
