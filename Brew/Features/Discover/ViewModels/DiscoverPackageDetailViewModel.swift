import Foundation
import Observation

@Observable
@MainActor
final class DiscoverPackageDetailViewModel {
    private(set) var discoveryPackage: DiscoveryBrewPackage
    @ObservationIgnored private let installedRepository: any InstalledPackageStatusReading

    init(package: DiscoveryBrewPackage, installedRepository: any InstalledPackageStatusReading) {
        discoveryPackage = package
        self.installedRepository = installedRepository
    }

    private var installedPackage: InstalledBrewPackage? {
        installedRepository.info(for: discoveryPackage.id)
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

    var packageDescription: String? {
        let trimmed = discoveryPackage.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var dependencyNames: [String] {
        discoveryPackage.dependencies.map(\.name)
    }

    var stableVersionLabel: String {
        discoveryPackage.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var installs30DayLabel: String {
        discoveryPackage.thirtyDayInstallCount.formatted()
    }

    /// Catalogue search results carry no analytics (zero install count), so the stat is hidden for them.
    var showsInstallMetrics: Bool {
        discoveryPackage.thirtyDayInstallCount > 0
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

    var installedStatusLabel: String? {
        guard installedPackage != nil else {
            return nil
        }
        return String(localized: "Installed", comment: "Discover package installed status")
    }

    var installedVersionLabel: String? {
        guard let raw = installedPackage?.installedVersions.first else {
            return nil
        }
        return InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
    }

    func update(package: DiscoveryBrewPackage) {
        discoveryPackage = package
    }
}
