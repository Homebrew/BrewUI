//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import SwiftUI

@main
struct BrewApp: App {
    private let commandCenter: SerialBrewCommandCenter
    private let installedInventoryCache: InstalledInventoryCache
    private let catalogueCache: CatalogueCache
    private let installedPackagesRepository: BrewInstalledPackagesRepository
    private let commandJobsRepository: BrewCommandJobsRepository

    init() {
        installedInventoryCache = InstalledInventoryCache()
        catalogueCache = CatalogueCache()
        commandCenter = SerialBrewCommandCenter(executionContext: .live())
        installedPackagesRepository = BrewInstalledPackagesRepository.live(
            cache: installedInventoryCache,
            commandCenter: commandCenter,
        )
        commandJobsRepository = BrewCommandJobsRepository(commandCenter: commandCenter)
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.installedInventoryCache, installedInventoryCache)
                .environment(\.catalogueCache, catalogueCache)
                .environment(\.installedPackagesRepository, installedPackagesRepository)
                .environment(\.commandJobsRepository, commandJobsRepository)
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
