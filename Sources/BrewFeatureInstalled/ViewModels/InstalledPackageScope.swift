//
//  InstalledPackageScope.swift
//  BrewFeatureInstalled
//

import Foundation

/// Package-kind filter for the Installed and Upgrades list scope pickers. Mirrors the Discover tab's
/// `DiscoverSearchScope`: it filters the already-loaded inventory client-side and never refetches.
///
/// Both `InstalledViewModel` and `UpgradesViewModel` project through this scope on top of the active
/// search query, so the two lists share one filtering vocabulary.
enum InstalledPackageScope: CaseIterable, Equatable {
    case all
    case formulae
    case casks
}
