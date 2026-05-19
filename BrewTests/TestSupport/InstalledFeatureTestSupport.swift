@testable import Brew
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [InstalledBrewPackage] = [],
        casks: [InstalledBrewPackage] = [],
    ) async -> InstalledViewModel {
        let cache = InstalledInventoryCache()
        let snapshot = InstalledInventorySnapshot(fetchedAt: .now, packages: formulae + casks)
        await cache.replace(snapshot)
        let repository = InstalledPackagesTestSupport.repository(
            commandRunner: MockBrewCommandRunner(responses: [:]),
            cache: cache,
        )
        let viewModel = InstalledViewModel(
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        await viewModel.load()
        return viewModel
    }
}

struct StubInstalledPackagesRepository: InstalledPackagesRepository {
    let snapshot: [InstalledBrewPackage]

    func loadInstalledPackages(forceRefresh _: Bool) async throws -> [InstalledBrewPackage] {
        snapshot
    }
}

struct StubInstalledDependentsRepository: InstalledDependentsRepository {
    let provider: @Sendable (InstalledBrewPackage.ID) -> [InstalledBrewPackage]

    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        provider(packageID)
    }
}

struct StubInstalledInventoryReading: InstalledInventoryReading {
    let installedIDs: Set<InstalledBrewPackage.ID>

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        installedIDs
    }
}
