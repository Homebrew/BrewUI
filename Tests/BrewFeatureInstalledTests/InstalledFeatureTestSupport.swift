import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoriesLive
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
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
