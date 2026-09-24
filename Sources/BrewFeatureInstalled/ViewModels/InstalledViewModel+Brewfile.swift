//
//  InstalledViewModel+Brewfile.swift
//  BrewFeatureInstalled
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation

/// The Installed header's "Save Brewfile…" action. Lives in its own extension so the list and
/// selection body of `InstalledViewModel` stays within the type-length budget.
extension InstalledViewModel {
    /// The header's "Save Brewfile…" action needs an inventory to dump, so it stays disabled until the
    /// repository has answered — the same gate the detail pane's uninstall uses.
    var canSaveBrewfile: Bool {
        state.value != nil
    }

    /// Saves the current environment as a Brewfile at `url` by running `brew bundle dump` through the
    /// command center, so the run streams in the console like every other `brew` invocation.
    ///
    /// The task is owned here rather than by the view's `.task` so it survives navigating away from the
    /// tab. One dump at a time: a second submission while one runs is ignored.
    func saveBrewfile(to url: URL) {
        guard !isSavingBrewfile else {
            return
        }
        let command = commandFactory.bundleDumpCommand(fileURL: url)
        let operationID = BrewOperationID(
            maintenanceToken: "bundleDump",
            displayCommand: command.displayCommand,
        )
        brewfileOutcome = nil
        isSavingBrewfile = true
        brewfileSaveTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                isSavingBrewfile = false
                brewfileSaveTask = nil
            }
            do {
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                if error is CancellationError {
                    return
                }
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                brewfileOutcome = .failed(message: saveFailureMessage(for: error, phase: latestPhase))
                return
            }
            brewfileOutcome = .saved(url: url)
        }
    }

    /// Prefers the failure the command center recorded (it carries `brew`'s own stderr) over the thrown
    /// error, which is the same failure seen one layer up.
    private func saveFailureMessage(for error: any Error, phase: BrewOperationPhase) -> String {
        if case let .failed(reason) = phase {
            return BrewErrorCopy.message(for: reason)
        }
        return BrewErrorCopy.message(
            for: error,
            fallback: String(
                localized: "Couldn't save the Brewfile.",
                bundle: #bundle,
                comment: "Installed tab, generic Brewfile save failure",
            ),
        )
    }
}
