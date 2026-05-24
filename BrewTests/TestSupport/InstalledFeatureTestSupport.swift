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
        let viewModel = InstalledViewModel(repository: repository)
        await viewModel.load()
        return viewModel
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
    let packages: [InstalledBrewPackage]

    init(
        installedIDs: Set<InstalledBrewPackage.ID>,
        packages: [InstalledBrewPackage] = [],
    ) {
        self.installedIDs = installedIDs
        self.packages = packages
    }

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        installedIDs
    }

    func installedPackages() async -> [InstalledBrewPackage] {
        if !packages.isEmpty {
            return packages
        }
        return []
    }
}
