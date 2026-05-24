import Foundation
import Observation

@Observable
@MainActor
final class DiscoverListRowViewModel: Identifiable {
    private(set) var discoveryPackage: DiscoveryBrewPackage
    /// Shared installed-status reader. Read through it so the installed badge/version stay reactive to
    /// installs and uninstalls happening on other surfaces.
    @ObservationIgnored let installedRepository: any InstalledPackageStatusReading

    init(
        discoveryPackage: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
    ) {
        self.discoveryPackage = discoveryPackage
        self.installedRepository = installedRepository
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

    private var installedPackage: InstalledBrewPackage? {
        installedRepository.info(for: id)
    }

    var installedVersionLabel: String? {
        guard let raw = installedPackage?.installedVersions.first else {
            return nil
        }
        return InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
    }

    var installedStatusLabel: String? {
        guard installedRepository.isInstalled(id) else {
            return nil
        }
        return String(localized: "Installed", comment: "Discover list row installed status")
    }

    func update(discoveryPackage newDiscoveryPackage: DiscoveryBrewPackage) {
        discoveryPackage = newDiscoveryPackage
    }

    func update(row: DiscoverListRowViewModel) {
        update(discoveryPackage: row.discoveryPackage)
    }
}
