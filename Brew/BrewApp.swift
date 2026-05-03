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

    init() {
        commandCenter = SerialBrewCommandCenter(executionContext: .live())
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(
                viewModel: MainWindowViewModel(
                    installedViewModel: InstalledViewModel(
                        repository: BrewInstalledPackagesRepository.live(),
                        detailsRepository: BrewPackageDetailsRepository.live(),
                    ),
                ),
            )
        }
        .defaultSize(
            width: BrewLayout.minWindowWidth,
            height: BrewLayout.minWindowHeight,
        )
    }
}
