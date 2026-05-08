@testable import Brew
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [BrewPackage] = [],
        casks: [BrewPackage] = [],
    ) async -> InstalledViewModel {
        let viewModel = InstalledViewModel(
            repository: StubInstalledPackagesRepository(
                snapshot: formulae + casks,
            ),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
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
