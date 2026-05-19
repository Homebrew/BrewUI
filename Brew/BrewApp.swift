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

    init() {
        installedInventoryCache = InstalledInventoryCache()
        catalogueCache = CatalogueCache()
        commandCenter = SerialBrewCommandCenter(executionContext: .live())
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.installedInventoryCache, installedInventoryCache)
                .environment(\.catalogueCache, catalogueCache)
                .task { await catalogueCache.prepare() }
        }
        .defaultSize(
            width: BrewLayout.minWindowWidth,
            height: BrewLayout.minWindowHeight,
        )
    }
}
