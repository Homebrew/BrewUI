//
//  MainSidebarView.swift
//  Brew
//

import BrewAccessibilityID
import BrewAppEnvironment
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

struct MainSidebarView: View {
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.systemImage)
                    .badge(badgeCount(for: item))
                    .tag(item)
                    .axid(.sidebarItem(item.axDestination))
            }
        }
        .listStyle(.sidebar)
        // `.contain` makes the sidebar itself an addressable container element without flattening
        // the rows inside it, so UI tests can scope a query to the sidebar.
        .accessibilityElement(children: .contain)
        .axid(.sidebar)
    }

    /// `.badge(0)` renders nothing, so rows without a count need no special case.
    private func badgeCount(for item: SidebarItem) -> Int {
        switch item {
        case .upgrades: installedPackagesRepository.outdatedCount
        case .installed, .discover, .doctor, .configuration: 0
        }
    }
}

#Preview {
    MainSidebarView(selection: .constant(.installed))
        .frame(width: BrewLayout.sidebarWidth, height: 400)
}
