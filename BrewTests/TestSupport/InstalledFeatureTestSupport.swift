@testable import Brew
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [BrewPackage] = [],
        casks: [BrewPackage] = [],
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
    let snapshot: [BrewPackage]

    func loadInstalledPackages(forceRefresh _: Bool) async throws -> [BrewPackage] {
        snapshot
    }
}

struct StubInstalledDependentsRepository: InstalledDependentsRepository {
    let provider: @Sendable (BrewPackage.ID) -> [BrewPackage]

    func installedDependents(for packageID: BrewPackage.ID) async -> [BrewPackage] {
        provider(packageID)
    }
}

struct StubInstalledInventoryReading: InstalledInventoryReading {
    let installedIDs: Set<BrewPackage.ID>

    func installedPackageIDs() async -> Set<BrewPackage.ID> {
        installedIDs
    }
}
