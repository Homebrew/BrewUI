//
//  UpgradesUpToDateCopy.swift
//  BrewFeatureInstalled
//

import Foundation

/// Single source for how the Upgrades tab says there is nothing to upgrade.
///
/// The tab makes that claim in four places at once — header subtitle, header action stand-in,
/// empty-state title and the empty state's VoiceOver label. Worded independently they read as four
/// different claims, so every one of them renders ``headline``; only ``installedDetail(count:)``
/// varies, and it reuses the same "up to date" phrasing.
enum UpgradesUpToDateCopy {
    static var headline: String {
        String(
            localized: "Everything is up to date",
            comment: "Upgrades tab: canonical phrase for having no upgrades available",
        )
    }

    /// Supporting line under ``headline``, carrying the installed count the claim covers.
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
