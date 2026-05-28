//
//  AppPreviewSupport.swift
//  BrewRepositoriesTestSupport
//

import BrewCore
import BrewCoreTestSupport
import BrewRepositories
import Foundation

/// Preview/test wiring built on repository stubs + ``BrewSampleData``. Feature previews import this to
/// obtain ready-made repositories and a no-op command center without touching `brew` or the network.
public enum AppPreviewSupport {
    public static let commandCenter = StubBrewCommandCenter()
    public static let mutatingCommandFactory = StubMutatingCommandFactory()

    // MARK: Sample data re-exports

    public static let discoverTopPackagesSnapshot = BrewSampleData.discoverTopPackagesSnapshot
    public static let discoverPreviewPackage = BrewSampleData.discoverPreviewPackage
    public static let discoverFormulaeCatalogue = BrewSampleData.discoverFormulaeCatalogue
    public static let discoverCasksCatalogue = BrewSampleData.discoverCasksCatalogue
    public static let outdatedFormula = BrewSampleData.outdatedFormula
    public static let currentFormula = BrewSampleData.currentFormula
    public static let currentCask = BrewSampleData.currentCask
    public static let installedPackages = BrewSampleData.installedPackages
    public static let emptyPackages = BrewSampleData.emptyPackages
    public static let installedInventoryIDs = BrewSampleData.installedInventoryIDs

    // MARK: Repository factories

    @MainActor
    public static func makeInstalledPackagesRepository(
        packages: [InstalledBrewPackage] = BrewSampleData.installedPackages,
    ) -> StubInstalledPackagesRepository {
        StubInstalledPackagesRepository(packages: packages)
    }

    @MainActor
    public static func makeInstalledDependentsRepository() -> any InstalledDependentsRepository {
        StubDependentsRepository(dependentsByPackageID: BrewSampleData.installedDependentsByPackageID)
    }

    @MainActor
    public static func makeInstalledInventoryReading() -> any InstalledInventoryReading {
        makeInstalledPackagesRepository()
    }

    @MainActor
    public static func makeDiscoverPackagesRepository() -> any DiscoverPackagesRepository {
        StubDiscoverPackagesRepository(snapshot: BrewSampleData.discoverTopPackagesSnapshot)
    }

    @MainActor
    public static func makeDiscoverCatalogueRepository() -> any CatalogueRepository {
        StubCatalogueRepository(
            formulaCatalogue: BrewSampleData.discoverFormulaeCatalogue,
            caskCatalogue: BrewSampleData.discoverCasksCatalogue,
        )
    }
}
