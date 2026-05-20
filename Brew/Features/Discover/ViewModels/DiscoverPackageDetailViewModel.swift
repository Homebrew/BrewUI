import Foundation
import Observation

@Observable
@MainActor
final class DiscoverPackageDetailViewModel {
    private(set) var discoveryPackage: DiscoveryPackage
    private(set) var installedPackage: InstalledBrewPackage?

    init(row: DiscoverListRowViewModel) {
        discoveryPackage = row.discoveryPackage
        installedPackage = row.installedPackage
    }

    var name: String {
        discoveryPackage.displayName
    }

    var packageKind: HomebrewPackageKind {
        discoveryPackage.kind
    }

    var packageKindChrome: PackageKindChrome {
        discoveryPackage.kind.chrome
    }

    var stableVersionLabel: String {
        discoveryPackage.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var installs30DayLabel: String {
        discoveryPackage.thirtyDayInstallCount.formatted()
    }

    var homepageURL: URL? {
        let trimmed = discoveryPackage.homepage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }

    var installCommand: String {
        switch discoveryPackage.kind {
        case .formula:
            "brew install \(discoveryPackage.name)"
        case .cask:
            "brew install --cask \(discoveryPackage.name)"
        }
    }

    var isInstalled: Bool {
        installedPackage != nil
    }

    var installedStatusText: String {
        if isInstalled {
            return String(localized: "Installed", comment: "Discover package already installed status")
        }
        return String(localized: "Not installed", comment: "Discover package not installed status")
    }

    var installedVersionLabel: String? {
        guard let raw = installedPackage?.installedVersions.first else {
            return nil
        }
        return InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
    }

    func update(row: DiscoverListRowViewModel) {
        discoveryPackage = row.discoveryPackage
        installedPackage = row.installedPackage
    }
}
