//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import BrewCLI
import BrewCore
import BrewFeatureConsole
import BrewNetworking
import BrewRepositories
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

@main
struct BrewApp: App {
    private let commandCenter: SerialBrewCommandCenter
    private let commandFactory: LiveBrewMutatingCommandFactory
    private let installedInventoryCache: InstalledInventoryCache
    private let catalogueCache: CatalogueCache
    private let installedPackagesRepository: BrewInstalledPackagesRepository
    private let commandJobsRepository: BrewCommandJobsRepository
    private let installedDependentsRepository: BrewInstalledDependentsRepository
    private let catalogueRepository: BrewCatalogueRepository
    private let discoverPackagesRepository: BrewDiscoverPackagesRepository

    init() {
        let inventoryCache = InstalledInventoryCache()
        let catalogue = CatalogueCache()
        let center = SerialBrewCommandCenter(executionContext: .live())
        let apiClient = URLSessionBrewAPIClient.live()
        let catalogueRepo = BrewCatalogueRepository(apiClient: apiClient, cache: catalogue)

        installedInventoryCache = inventoryCache
        catalogueCache = catalogue
        commandCenter = center
        commandFactory = LiveBrewMutatingCommandFactory()
        installedPackagesRepository = BrewInstalledPackagesRepository.live(
            cache: inventoryCache,
            commandCenter: center,
        )
        commandJobsRepository = BrewCommandJobsRepository(commandCenter: center)
        installedDependentsRepository = BrewInstalledDependentsRepository(cache: inventoryCache)
        catalogueRepository = catalogueRepo
        discoverPackagesRepository = BrewDiscoverPackagesRepository(
            apiClient: apiClient,
            catalogueRepository: catalogueRepo,
        )
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.mutatingCommandFactory, commandFactory)
                .environment(\.installedPackagesRepository, installedPackagesRepository)
                .environment(\.commandJobsRepository, commandJobsRepository)
                .environment(\.installedDependentsRepository, installedDependentsRepository)
                .environment(\.catalogueRepository, catalogueRepository)
                .environment(\.discoverPackagesRepository, discoverPackagesRepository)
                .task { await catalogueCache.prepare() }
                .task { await installedPackagesRepository.load() }
        }
        .defaultSize(
            width: BrewLayout.minWindowWidth,
            height: BrewLayout.minWindowHeight,
        )
        .commands {
            ConsoleCommands()
        }
        #if DEBUG
        .commands {
                DebugMenuCommands()
            }
        #endif
    }
}
