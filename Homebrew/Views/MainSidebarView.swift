//
//  MainSidebarView.swift
//  Brew
//

import BrewFeatureInstalled
import BrewUIComponents
import SwiftUI

struct MainSidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: BrewSpacing.sm) {
                Image("Mark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                Text("Homebrew")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
            }
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Homebrew")

            Divider()
                .overlay(Color.brewBorderSeparator)

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
    }

    @ViewBuilder
    private func sidebarRow(
        title: String,
        emoji: String,
        item: SidebarItem,
        @ViewBuilder trailingAccessory: () -> some View = { EmptyView() },
    ) -> some View {
        let isSelected = selection == item
        Button {
            selection = item
        } label: {
            HStack(spacing: BrewSpacing.sm) {
                Text("\(emoji) \(title)")
                    .font(.brewBody)
                    .foregroundStyle(isSelected ? Color.brewBrandPrimary : Color.brewTextPrimary)
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
    }
}

#Preview {
    MainSidebarView(selection: .constant(.installed))
        .frame(width: BrewLayout.sidebarWidth, height: 400)
}
