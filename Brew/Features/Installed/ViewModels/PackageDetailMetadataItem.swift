//
//  PackageDetailMetadataItem.swift
//  Brew
//

import Foundation

/// Presentation mapping for Installed detail metadata content.
nonisolated struct PackageDetailMetadataItem {
    private let package: InstalledBrewPackage

    init(package: InstalledBrewPackage) {
        self.package = package
    }

    /// User-facing command for package details transparency.
    var infoCommand: String {
        "brew info \(package.name)"
    }

    var latestVersionValue: String {
        formattedValue(package.latestVersion)
    }

    var installedVersionsValue: String {
        guard !package.installedVersions.isEmpty else {
            return "—"
        }
        return package.installedVersions.joined(separator: ", ")
    }

    /// Valid homepage URL for display, if available.
    var homepageURL: URL? {
        Self.validWebURL(from: package.homepage)
    }

    var homepageDisplayTitle: String? {
        guard let homepageURL else {
            return nil
        }
        if let host = homepageURL.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
        }
        return homepageURL.absoluteString
    }

    private func formattedValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
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
