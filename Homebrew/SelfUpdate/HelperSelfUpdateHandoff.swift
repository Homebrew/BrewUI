//
//  HelperSelfUpdateHandoff.swift
//  Brew
//

import AppKit
import BrewCore
import BrewRepositories
import BrewRepositoryInterfaces
import BrewSelfUpdateContract
import Foundation

struct HelperSelfUpdateHandoff: SelfUpdateHandoff {
    /// Resolved here rather than in the helper: the app already knows which `brew` it has been talking to,
    /// and a failure to find one should stop the handoff instead of quitting into a helper that cannot work.
    let brewExecutableURL: @MainActor () throws -> URL
    let defaultsKeyPrefix: String
    /// Carried across the relaunch so a UI-test run comes back still pointed at its fixtures.
    let relaunchArguments: [String]
    let relaunchEnvironment: [String: String]
    let upgradeEnvironment: [String: String]
    let logFileURL: URL

    func performUpdate() async throws {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/HomebrewUpdateHelper")
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw SelfUpdateHelperUnavailable()
        }
        // Before anything is written or quit: `brew` missing is the one failure the app can still report.
        let brewURL = try brewExecutableURL()

        let specURL = try writeSpec(brewExecutableURL: brewURL)
        let process = Process()
        process.executableURL = helperURL
        process.arguments = [SelfUpdateHandoffDefaults.specPathArgument, specURL.path]
        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: specURL)
            throw error
        }

        // After the helper is running: it polls for this process to disappear, so quitting first races it.
        NSApplication.shared.terminate(nil)
    }

    private func writeSpec(brewExecutableURL: URL) throws -> URL {
        let spec = SelfUpdateHandoffSpec(
            parentProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            appBundlePath: Bundle.main.bundleURL.path,
            relaunchArguments: relaunchArguments,
            relaunchEnvironment: relaunchEnvironment,
            brewExecutablePath: brewExecutableURL.path,
            upgradeArguments: BrewCommands.selfUpgrade().arguments,
            upgradeEnvironment: upgradeEnvironment,
            logFilePath: logFileURL.path,
            defaultsSuiteName: Bundle.main.bundleIdentifier ?? SelfUpdateIdentity.bundleIdentifier,
            noticeKey: SelfUpdateLaunchNotice(defaultsKeyPrefix: defaultsKeyPrefix).storageKey,
            successValue: SelfUpdateOutcome.succeeded.rawValue,
            failureValue: SelfUpdateOutcome.failed.rawValue,
            waitForExitTimeout: SelfUpdateHandoffDefaults.waitForExitTimeout,
            upgradeTimeout: SelfUpdateHandoffDefaults.upgradeTimeout,
        )
        let specURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("self-update-handoff-\(UUID().uuidString).json")
        try spec.encoded().write(to: specURL, options: .atomic)
        return specURL
    }
}

private struct SelfUpdateHelperUnavailable: LocalizedError {
    var errorDescription: String? {
        String(
            localized: "The update helper is missing from this build of the Homebrew app.",
            comment: "Shown when the bundled self-update helper executable cannot be found",
        )
    }
}
