//
//  BrewfileCommands.swift
//  Homebrew
//

import AppKit
import BrewCore
import SwiftUI

/// File menu commands for saving the installed environment as a Brewfile.
struct BrewfileCommands: Commands {
    @FocusedValue(\.saveBrewfile) private var saveBrewfile

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(String(localized: "Save Brewfile…", bundle: #bundle, comment: "File menu: save the installed packages as a Brewfile")) { saveBrewfile?() }
                .disabled(saveBrewfile == nil)
        }
    }
}

/// Asks where to save, then lets `brew bundle dump` write the file so Homebrew owns its contents.
struct SaveBrewfileAction {
    let commandCenter: any BrewCommandCenter
    let commandFactory: any BrewMutatingCommandFactory

    @MainActor
    func callAsFunction() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Brewfile"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let command = commandFactory.bundleDumpCommand(fileURL: url)
        let id = BrewOperationID(maintenanceToken: "bundleDump", displayCommand: command.displayCommand)
        Task {
            // The console shows the run's outcome, including brew's stderr when it fails.
            try? await commandCenter.perform(command, id: id)
        }
    }
}

extension FocusedValues {
    @Entry var saveBrewfile: SaveBrewfileAction?
}
