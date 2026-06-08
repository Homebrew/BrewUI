//
//  MainSidebarView.swift
//  Brew
//

import BrewFeatureInstalled
import BrewUIComponents
import SwiftUI

/// Primary navigation items for the main window sidebar.
enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case installed
    case upgrades
    case discover
    case doctor
    case configuration

    var id: String {
        rawValue
    }
}

struct MainSidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: BrewSpacing.sm) {
                Text("🍺")
                    .font(.brewTitle2)
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
                systemImage: "cube.box.fill",
                item: .installed,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.top, BrewSpacing.sm)

            sidebarRow(
                title: "Upgrades",
                systemImage: "arrow.triangle.2.circlepath",
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
        .background(Color.brewSurfaceRecessed)
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
                    .foregroundStyle(isSelected ? Color.brewBrandPrimary : Color.brewTextSecondary)
                    .imageScale(.medium)
                Text(title)
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
