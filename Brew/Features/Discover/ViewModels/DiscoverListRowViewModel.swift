import Foundation
import Observation

@Observable
@MainActor
final class DiscoverListRowViewModel: Identifiable {
    private(set) var discoveryPackage: DiscoveryBrewPackage
    private(set) var installedPackage: InstalledBrewPackage?

    init(
        discoveryPackage: DiscoveryBrewPackage,
        installedPackage: InstalledBrewPackage?,
    ) {
        self.discoveryPackage = discoveryPackage
        self.installedPackage = installedPackage
    }

    var id: BrewPackage.ID {
        discoveryPackage.id
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

    var descriptionText: String {
        discoveryPackage.description
    }

    var hasDescription: Bool {
        !descriptionText.isEmpty
    }

    var thirtyDayInstallCount: Int {
        discoveryPackage.thirtyDayInstallCount
    }

    var installs30DayLabel: String {
        thirtyDayInstallCount.formatted()
    }

    var stableVersionLabel: String {
        discoveryPackage.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isInstalled: Bool {
        installedPackage != nil
    }

    var installedVersionLabel: String? {
        guard let raw = installedPackage?.installedVersions.first else {
            return nil
        }
        return InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
    }

    var installedStatusLabel: String {
        if isInstalled {
            return String(localized: "Installed", comment: "Discover list row installed status")
        }
        return String(localized: "Not installed", comment: "Discover list row not installed status")
    }

    func update(
        discoveryPackage newDiscoveryPackage: DiscoveryBrewPackage,
        installedPackage newInstalledPackage: InstalledBrewPackage?,
    ) {
        discoveryPackage = newDiscoveryPackage
        installedPackage = newInstalledPackage
    }

    func update(row: DiscoverListRowViewModel) {
        update(
            discoveryPackage: row.discoveryPackage,
            installedPackage: row.installedPackage,
        )
    }
}
