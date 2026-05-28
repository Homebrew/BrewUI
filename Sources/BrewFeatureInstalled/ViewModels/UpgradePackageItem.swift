//
//  UpgradePackageItem.swift
//  Brew
//

import BrewCore
import BrewDesignSystem
import BrewRepositories
import Foundation

/// Presentation mapping for upgrade actions shown in Installed package detail.
nonisolated struct UpgradePackageItem {
    private let package: InstalledBrewPackage

    init(package: InstalledBrewPackage) {
        self.package = package
    }

    var showsUpgradeChrome: Bool {
        package.outdated
    }

    /// Copyable Terminal command for upgrading this package (`CONVENTIONS.md` — transparency).
    var displayCommand: String {
        switch package.kind {
        case .formula:
            "brew upgrade --formula \(package.name)"
        case .cask:
            "brew upgrade --cask \(package.name)"
        }
    }

    /// Primary upgrade button label when the package is outdated.
    var primaryButtonTitle: String? {
        guard showsUpgradeChrome else {
            return nil
        }
        guard let label = InstalledBrewVersionFormatting.upgradeDisplayLabel(from: package.latestVersion) else {
            return nil
        }
        return String(
            localized: "Update to \(label)",
            comment: "Installed detail upgrade button; interpolated label shows target tap version.",
        )
    }
}
