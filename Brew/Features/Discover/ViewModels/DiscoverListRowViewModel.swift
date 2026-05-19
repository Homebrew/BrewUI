import Foundation
import Observation

@Observable
@MainActor
final class DiscoverListRowViewModel: Identifiable {
    private(set) var package: BrewPackage
    private(set) var analyticsInstallCount: Int
    private(set) var installedPackage: InstalledBrewPackage?

    init(
        package: BrewPackage,
        analyticsInstallCount: Int,
        installedPackage: InstalledBrewPackage?,
    ) {
        self.package = package
        self.analyticsInstallCount = analyticsInstallCount
        self.installedPackage = installedPackage
    }

    var id: BrewPackage.ID {
        package.id
    }

    var name: String {
        package.displayName
    }

    var packageKind: HomebrewPackageKind {
        package.kind
    }

    var packageKindChrome: PackageKindChrome {
        package.kind.chrome
    }

    var descriptionText: String {
        package.description
    }

    var hasDescription: Bool {
        !descriptionText.isEmpty
    }

    var installs30DayLabel: String {
        analyticsInstallCount.formatted()
    }

    var stableVersionLabel: String {
        let trimmed = package.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
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
        package newPackage: BrewPackage,
        analyticsInstallCount newAnalyticsInstallCount: Int,
        installedPackage newInstalledPackage: InstalledBrewPackage?,
    ) {
        package = newPackage
        analyticsInstallCount = newAnalyticsInstallCount
        installedPackage = newInstalledPackage
    }

    func update(row: DiscoverListRowViewModel) {
        update(
            package: row.package,
            analyticsInstallCount: row.analyticsInstallCount,
            installedPackage: row.installedPackage,
        )
    }
}
