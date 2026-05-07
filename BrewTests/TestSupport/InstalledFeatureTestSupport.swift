@testable import Brew
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [BrewPackage] = [],
        casks: [BrewPackage] = [],
        details: BrewPackage? = nil,
    ) async -> InstalledViewModel {
        _ = details
        let viewModel = InstalledViewModel(
            repository: StubInstalledPackagesRepository(
                snapshot: formulae + casks,
            ),
        )
        await viewModel.load()
        return viewModel
    }
}

struct StubInstalledPackagesRepository: InstalledPackagesRepository {
    let snapshot: [BrewPackage]

    func loadInstalledPackages() async throws -> [BrewPackage] {
        snapshot
    }
}

struct StubPackageDetailsRepository: PackageDetailsRepository {
    let details: BrewPackage?

    init(details: BrewPackage? = nil) {
        self.details = details
    }

    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind?,
    ) async throws -> BrewPackage {
        if let details {
            return details
        }
        return BrewPackage(
            name: name,
            kind: preferredKind ?? .formula,
            description: "desc",
            homepage: nil,
            latestVersion: "1.0.0",
            installedVersions: ["1.0.0"],
            dependencies: [],
            outdated: false,
        )
    }
}
