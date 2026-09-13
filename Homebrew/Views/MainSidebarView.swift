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
                systemImage: "shippingbox",
                item: .installed,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.sm)

            sidebarRow(
                title: "Upgrades",
                systemImage: "arrow.up.circle",
                item: .upgrades,
                trailingAccessory: { UpgradesSidebarBadge() },
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            sidebarRow(
                title: "Discover",
                systemImage: "magnifyingglass",
                item: .discover,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            sidebarRow(
                title: "Doctor",
                systemImage: "stethoscope",
                item: .doctor,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            sidebarRow(
                title: "Configuration",
                systemImage: "gearshape",
                item: .configuration,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.xs)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.brewSurface)
        .accessibilityElement(children: .contain)
        .axid(.sidebar)
    }

    @ViewBuilder
    private func sidebarRow(
        title: String,
        systemImage: String,
        item: SidebarItem,
        @ViewBuilder trailingAccessory: () -> some View = { EmptyView() },
    ) -> some View {
        let isSelected = selection == item
        Button {
            selection = item
        } label: {
            HStack(spacing: BrewSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.brewBody)
                    .frame(width: 20, alignment: .center)

                Text(title)
                    .font(.brewBody)

                Spacer(minLength: 0)

                trailingAccessory()
            }
            .foregroundStyle(
                isSelected
                    ? Color.brewTextBrand
                    : Color.brewTextPrimary,
            )
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: BrewRadius.md)
                    .fill(isSelected ? Color.brewBrandTint : Color.clear,)
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
