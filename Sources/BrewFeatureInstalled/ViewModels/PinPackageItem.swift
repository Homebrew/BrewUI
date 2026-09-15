//
//  PinPackageItem.swift
//  Brew
//

import BrewCore
import Foundation

/// Presentation mapping for pin and unpin actions shown in Installed package detail.
struct PinPackageItem {
    private let package: InstalledBrewPackage

    init(package: InstalledBrewPackage) {
        self.package = package
    }

    var isPinned: Bool {
        package.pinned
    }

    /// Copyable Terminal command for the pin or unpin action currently offered.
    var displayCommand: String {
        let verb = isPinned ? "unpin" : "pin"
        switch package.kind {
        case .formula:
            "brew \(verb) --formula \(package.name)"
        case .cask:
            "brew \(verb) --cask \(package.name)"
        }
    }

    var sectionTitle: String {
        isPinned
            ? String(localized: "Unpin", comment: "Installed detail unpin section title")
            : String(localized: "Pin", comment: "Installed detail pin section title")
    }

    var primaryButtonTitle: String {
        sectionTitle
    }

    var summaryText: String {
        if isPinned {
            return String(
                localized: "Allows brew upgrade to update this package again",
                comment: "Installed detail unpin command summary",
            )
        }
        return String(
            localized: "Prevents brew upgrade from updating this package",
            comment: "Installed detail pin command summary",
        )
    }
}
