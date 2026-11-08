import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [InstalledBrewPackage] = [],
        casks: [InstalledBrewPackage] = [],
        preferences: any InstalledPreferences = StubInstalledPreferences(),
        aiEngine: (any AIEngineProtocol)? = nil,
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
            preferences: preferences,
            aiEngine: aiEngine,
            commandFactory: StubMutatingCommandFactory(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        await viewModel.load()
        return viewModel
    }
}
