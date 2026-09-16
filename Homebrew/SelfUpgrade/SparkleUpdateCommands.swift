//
//  SparkleUpdateCommands.swift
//  Brew
//

import SwiftUI

struct SparkleUpdateCommands: Commands {
    @Bindable var updater: SparkleUpdateController

    var body: some Commands {
        if updater.isConfigured {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
