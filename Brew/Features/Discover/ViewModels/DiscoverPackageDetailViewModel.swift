import Foundation
import Observation

@Observable
@MainActor
final class DiscoverPackageDetailViewModel {
    private(set) var package: BrewPackage
    private(set) var analyticsInstallCount: Int
    private(set) var installedPackage: InstalledBrewPackage?

    init(row: DiscoverListRowViewModel) {
        package = row.package
        analyticsInstallCount = row.analyticsInstallCount
        installedPackage = row.installedPackage
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

    var stableVersionLabel: String {
        let trimmed = package.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    var installs30DayLabel: String {
        analyticsInstallCount.formatted()
    }

    var homepageURL: URL? {
        let trimmed = package.homepage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }

    var installCommand: String {
        switch package.kind {
        case .formula:
            "brew install \(package.name)"
        case .cask:
            "brew install --cask \(package.name)"
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
        package = row.package
        analyticsInstallCount = row.analyticsInstallCount
        installedPackage = row.installedPackage
    }
}
