//
//  PackageDetailMetadataItem.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation

/// Presentation mapping for Installed detail metadata content.
struct PackageDetailMetadataItem {
    private let package: InstalledBrewPackage

    private static let installDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

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

    /// Installed version(s). Only annotates the active keg with "(linked)" when multiple versions
    /// are installed side-by-side — in the common single-version case the annotation adds no information.
    var installedVersionsValue: String {
        guard !package.installedVersions.isEmpty else {
            return "—"
        }
        let joined = package.installedVersions.joined(separator: ", ")
        guard package.installedVersions.count > 1, package.linkedKeg != nil else {
            return joined
        }
        return "\(joined) (linked)"
    }

    /// Nil when there is no install date to show.
    var installDateValue: String? {
        guard let date = package.installDate else { return nil }
        let formatted = Self.installDateFormatter.string(from: date)
        return package.pouredFromBottle ? "Poured from bottle — \(formatted)" : formatted
    }

    /// Nil when the package was installed on request (the default); non-nil for dependency installs.
    var installReasonValue: String? {
        package.installedOnRequest ? nil : "As dependency"
    }

    var licenseValue: String? {
        guard let license = package.license, !license.isEmpty else { return nil }
        return license
    }

    /// Display label for the source tap, e.g. "homebrew/core".
    var tapDisplayValue: String? {
        package.tap
    }

    /// Direct link to the formula's source on GitHub, derived from ``InstalledBrewPackage/formulaSourceURL``.
    var sourceURL: URL? {
        package.formulaSourceURL
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

    var isOutdated: Bool {
        package.outdated
    }

    var isPinned: Bool {
        package.pinned
    }

    var isKegOnly: Bool {
        package.kegOnly
    }

    var caveatsText: String? {
        guard let caveats = package.caveats, !caveats.isEmpty else { return nil }
        return caveats
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
