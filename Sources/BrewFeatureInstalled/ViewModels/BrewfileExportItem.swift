//
//  BrewfileExportItem.swift
//  BrewFeatureInstalled
//

import BrewCore
import Foundation

/// Presentation mapping for a Brewfile export destination: display path, copyable command, and the
/// maintenance identity the console stores. Homebrew still serializes the Brewfile; this type does not.
struct BrewfileExportItem: Equatable {
    let destinationURL: URL
    let destinationPath: String
    let displayCommand: String
    let operationID: BrewOperationID

    init(destinationURL: URL) {
        let standardized = destinationURL.standardizedFileURL
        self.destinationURL = standardized
        destinationPath = standardized.path
        displayCommand = Self.displayCommand(filePath: destinationPath)
        operationID = BrewOperationID(
            maintenanceToken: "bundle-dump:\(destinationPath)",
            displayCommand: displayCommand,
        )
    }

    var showInFinderButtonTitle: String {
        Self.showInFinderButtonTitle
    }

    var successTitle: String {
        Self.successTitle
    }

    var successMessage: String {
        String(
            localized: "Saved to \(destinationPath)",
            comment: "Brewfile export success detail; interpolated destination path",
        )
    }

    var commandSummary: String {
        Self.commandSummary
    }

    static let sheetTitle = String(
        localized: "Export Brewfile",
        comment: "Brewfile export sheet title",
    )

    static let headerButtonTitle = String(
        localized: "Export Brewfile…",
        comment: "Installed header button that opens the Brewfile export sheet",
    )

    static let chooseLocationButtonTitle = String(
        localized: "Choose Location…",
        comment: "Brewfile export sheet button that opens the save panel",
    )

    static let exportButtonTitle = String(
        localized: "Export",
        comment: "Brewfile export sheet button that runs brew bundle dump",
    )

    static let showInFinderButtonTitle = String(
        localized: "Show in Finder",
        comment: "Brewfile export sheet button that reveals the saved file",
    )

    static let successTitle = String(
        localized: "Brewfile exported",
        comment: "Brewfile export sheet success heading",
    )

    static let explainer = String(
        localized: """
        Homebrew will export the formulae and casks it considers installed on request, plus the taps \
        needed to restore them. Dependencies are chosen by Homebrew, not by this list. This sheet only \
        writes a Brewfile; it does not import or install packages.
        """,
        comment: "Brewfile export sheet explanation of dump scope; import is out of scope",
    )

    static let commandSummary = String(
        localized: "Writes formulae, casks, and taps using brew bundle dump.",
        comment: "Brewfile export sheet summary under the copyable command",
    )

    static let progressTitle = String(
        localized: "Exporting Brewfile…",
        comment: "Brewfile export sheet progress label while brew bundle dump runs",
    )

    /// Copyable Terminal rendering of the exact argv scheduled for `filePath`.
    static func displayCommand(filePath: String) -> String {
        "brew bundle dump --file=\(shellQuote(filePath)) --force --formula --cask --tap"
    }

    /// POSIX single-quote escaping when `value` is not already safe unquoted.
    static func shellQuote(_ value: String) -> String {
        if !value.isEmpty, value.unicodeScalars.allSatisfy({ unquotedSafeCharacters.contains($0) }) {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static let unquotedSafeCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-_./:@+"))
}
