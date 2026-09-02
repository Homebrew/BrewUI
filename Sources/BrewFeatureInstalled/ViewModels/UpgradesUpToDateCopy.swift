//
//  UpgradesUpToDateCopy.swift
//  BrewFeatureInstalled
//

import Foundation

/// One phrase for "nothing to upgrade", shared by the four places the tab makes that claim at once.
enum UpgradesUpToDateCopy {
    static var headline: String {
        String(
            localized: "Everything is up to date",
            comment: "Upgrades tab: canonical phrase for having no upgrades available",
        )
    }

    static func installedDetail(count: Int) -> String {
        switch count {
        case 0:
            String(
                localized: "No installed packages to check.",
                comment: "Upgrades empty state when nothing is installed",
            )
        case 1:
            String(
                localized: "Your installed package is up to date.",
                comment: "Upgrades empty state for a single installed package",
            )
        default:
            String(
                localized: "All \(count) installed packages are up to date.",
                comment: "Upgrades empty state with total installed count",
            )
        }
    }
}
