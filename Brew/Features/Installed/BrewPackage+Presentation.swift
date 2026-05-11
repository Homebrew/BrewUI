//
//  BrewPackage+Presentation.swift
//  Brew
//

import Foundation

extension BrewPackage {
    /// Valid homepage URL for display, if available.
    var homepageURL: URL? {
        Self.validWebURL(from: homepage)
    }

    /// User-facing `brew info` command for this package.
    var infoCommand: String {
        "brew info \(name)"
    }

    /// Copyable Terminal command for upgrading this package (`CONVENTIONS.md` — transparency).
    var upgradeCommand: String {
        switch kind {
        case .formula:
            "brew upgrade --formula \(name)"
        case .cask:
            "brew upgrade --cask \(name)"
        }
    }

    /// Primary upgrade button label when ``outdated``; nil when not outdated or version label is missing.
    var upgradeButtonTitle: String? {
        guard outdated else {
            return nil
        }
        guard let label = InstalledBrewVersionFormatting.upgradeDisplayLabel(from: latestVersion) else {
            return nil
        }
        return String(
            localized: "Update to \(label)",
            comment: "Installed detail upgrade button; interpolated label shows target tap version.",
        )
    }

    private static func validWebURL(from rawValue: String?) -> URL? {
        guard let rawValue else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return url
    }
}
