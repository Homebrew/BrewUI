//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import SwiftUI

@main
struct BrewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(
            width: BrewLayout.minWindowWidth,
            height: BrewLayout.minWindowHeight,
        )
    }
}
