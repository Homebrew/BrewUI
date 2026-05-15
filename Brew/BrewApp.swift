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

    init() {
        installedInventoryCache = InstalledInventoryCache()
        commandCenter = SerialBrewCommandCenter(executionContext: .live())
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.installedInventoryCache, installedInventoryCache)
        }
        .defaultSize(
            width: BrewLayout.minWindowWidth,
            height: BrewLayout.minWindowHeight,
        )
    }
}
