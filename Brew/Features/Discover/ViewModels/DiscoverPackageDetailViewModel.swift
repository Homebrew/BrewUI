import Foundation
import Observation

@Observable
@MainActor
final class DiscoverPackageDetailViewModel {
    private(set) var discoveryPackage: DiscoveryBrewPackage
    @ObservationIgnored private let installedRepository: any InstalledPackageStatusReading

    init(row: DiscoverListRowViewModel) {
        discoveryPackage = row.discoveryPackage
        installedRepository = row.installedRepository
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

    func update(row: DiscoverListRowViewModel) {
        discoveryPackage = row.discoveryPackage
    }
}
