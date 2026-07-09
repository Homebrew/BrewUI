//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import BrewAppEnvironment
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
    /// Homebrew's online documentation, surfaced from the Help menu.
    private static let documentationURL = URL(string: "https://docs.brew.sh/")!

    @Environment(\.scenePhase) private var scenePhase

    private let commandCenter: SerialBrewCommandCenter
    private let commandFactory: LiveBrewMutatingCommandFactory
    private let installedInventoryCache: InstalledInventoryCache
    private let catalogueCache: CatalogueCache
    private let discoverAnalyticsCache: DiscoverAnalyticsCache
    private let installedPackagesRepository: BrewInstalledPackagesRepository
    private let commandJobsRepository: BrewCommandJobsRepository
    private let installedDependentsRepository: BrewInstalledDependentsRepository
    private let catalogueRepository: BrewCatalogueRepository
    private let discoverPackagesRepository: BrewDiscoverPackagesRepository
    private let doctorRepository: BrewDoctorRepository
    private let configRepository: BrewConfigRepository

    init() {
        let inventoryCache = InstalledInventoryCache()
        let catalogue = CatalogueCache()
        let discoverAnalytics = DiscoverAnalyticsCache()
        let center = SerialBrewCommandCenter(executionContext: .live())
        let apiClient = URLSessionBrewAPIClient.live()
        let catalogueRepo = BrewCatalogueRepository(apiClient: apiClient, cache: catalogue)

        installedInventoryCache = inventoryCache
        catalogueCache = catalogue
        discoverAnalyticsCache = discoverAnalytics
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
            cache: discoverAnalytics,
        )
        doctorRepository = BrewDoctorRepository(commandCenter: center)
        configRepository = BrewConfigRepository.live()
        NSWindow.allowsAutomaticWindowTabbing = false
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
                .environment(\.doctorRepository, doctorRepository)
                .environment(\.configRepository, configRepository)
                .task { await catalogueCache.prepare() }
                .task { await discoverAnalyticsCache.prepare() }
                .task { await installedPackagesRepository.load() }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Mark the config + brew.env caches stale on return-to-foreground so the next visit
                    // to the Configuration tab triggers a silent revalidation (stale value stays on
                    // screen during the refetch). No work is done if the user never opens the tab.
                    guard oldPhase == .background, newPhase == .active else {
                        return
                    }
                    configRepository.invalidate()
                }
                .frame(
                    minWidth: BrewLayout.minWindowWidth,
                    minHeight: BrewLayout.minWindowHeight,
                )
        }
        .defaultSize(
            width: BrewLayout.defaultWindowWidth,
            height: BrewLayout.defaultWindowHeight,
        )
        .commands {
            SearchCommands()
            SidebarCommands()
            ConsoleCommands()

            // Replace the default "Homebrew Help" item (which points at a
            // non-existent help book) with a link to the online documentation.
            CommandGroup(replacing: .help) {
                Link("Homebrew Documentation", destination: Self.documentationURL)
            }
        }
        #if DEBUG
        .commands {
                DebugMenuCommands()
            }
        #endif
    }
}
