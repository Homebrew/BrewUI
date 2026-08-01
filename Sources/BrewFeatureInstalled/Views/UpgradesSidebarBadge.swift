//
//  UpgradesSidebarBadge.swift
//  BrewFeatureInstalled
//

import BrewAppEnvironment
import BrewUIComponents
import SwiftUI

/// Warning-tinted count badge for the Upgrades sidebar row.
/// Reads the installed-packages repository so SwiftUI re-renders when an
/// upgrade reconciles the inventory and the outdated count changes.
public struct UpgradesSidebarBadge: View {
    @Environment(\.installedPackagesRepository) private var repository
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let count = repository.outdatedCount
        if count > 0 {
            Text("\(count)")
                .font(.brewCaption2.weight(.semibold))
                // Knock the count out of the amber pill using the sidebar panel's own
                // background in dark mode; plain white still reads best in light mode.
                .foregroundStyle(colorScheme == .dark ? Color.brewSurface : Color.white)
                .padding(.horizontal, BrewSpacing.xs)
                .padding(.vertical, BrewSpacing.xxs)
                .background(Capsule().fill(Color.brewStatusWarning))
                .accessibilityLabel("\(count) upgrades available")
        }
    }
}
