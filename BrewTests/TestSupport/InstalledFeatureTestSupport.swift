@testable import Brew
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [InstalledPackageInfo] = [],
        casks: [InstalledPackageInfo] = [],
        details: InstalledPackageDetails? = nil,
    ) async -> InstalledViewModel {
        let viewModel = InstalledViewModel(
            repository: StubInstalledPackagesRepository(
                snapshot: InstalledPackagesSnapshot(formulae: formulae, casks: casks),
            ),
            detailsRepository: StubPackageDetailsRepository(details: details),
        )
        await viewModel.load()
        return viewModel
    }
}

struct StubInstalledPackagesRepository: InstalledPackagesRepository {
    let snapshot: InstalledPackagesSnapshot

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        snapshot
    }
}

struct StubPackageDetailsRepository: PackageDetailsRepository {
    let details: InstalledPackageDetails?

    init(details: InstalledPackageDetails? = nil) {
        self.details = details
    }

    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind?,
    ) async throws -> InstalledPackageDetails {
        if let details {
            return details
        }
        return InstalledPackageDetails(
            name: name,
            kind: preferredKind ?? .formula,
            description: "desc",
            version: "1.0.0",
            installedVersions: ["1.0.0"],
            homepage: nil,
            dependencies: [],
        )
    }
}
