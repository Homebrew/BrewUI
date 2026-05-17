//
//  UninstallPackageItem.swift
//  Brew
//

import Foundation

/// Presentation mapping for uninstall actions shown in Installed package detail subviews.
struct UninstallPackageItem {
    private let package: BrewPackage

    init(package: BrewPackage) {
        self.package = package
    }

    /// Copyable Terminal command for uninstalling this package (`CONVENTIONS.md` — transparency).
    var displayCommand: String {
        switch package.kind {
        case .formula:
            "brew uninstall --formula \(package.name)"
        case .cask:
            "brew uninstall --cask \(package.name)"
        }
    }

    /// Primary uninstall button label.
    var primaryButtonTitle: String {
        String(
            localized: "Uninstall",
            comment: "Installed detail uninstall button title",
        )
    }

    /// Confirmation title shown before uninstalling this package.
    var confirmationTitle: String {
        String(
            localized: "Uninstall \(package.name)?",
            comment: "Installed detail uninstall confirmation title; interpolated package name",
        )
    }

    /// Confirmation detail shown before uninstalling this package.
    var confirmationMessage: String {
        String(
            localized: "This will remove \(package.name) from this Mac using Homebrew.",
            comment: "Installed detail uninstall confirmation message; interpolated package name",
        )
    }
}
