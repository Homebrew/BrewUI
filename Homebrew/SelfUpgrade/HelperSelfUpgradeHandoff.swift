//
//  HelperSelfUpgradeHandoff.swift
//  Brew
//

import AppKit
import BrewCore
import BrewRepositories
import BrewRepositoryInterfaces
import BrewSelfUpgradeContract
import Foundation

struct HelperSelfUpgradeHandoff: SelfUpgradeHandoff {
    /// Resolved here rather than in the helper: the app already knows which `brew` it has been talking to,
    /// and a failure to find one should stop the handoff instead of quitting into a helper that cannot work.
    let brewExecutableURL: @MainActor () throws -> URL
    let defaultsKeyPrefix: String
    /// Carried across the relaunch so a UI-test run comes back still pointed at its fixtures.
    let relaunchArguments: [String]
    let relaunchEnvironment: [String: String]
    let upgradeEnvironment: [String: String]
    let logFileURL: URL

    func performUpgrade() async throws {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/HomebrewUpgradeHelper")
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw SelfUpgradeHelperUnavailable()
        }
        // Before anything is written or quit: `brew` missing is the one failure the app can still report.
        let brewURL = try brewExecutableURL()

        let specURL = try writeSpec(brewExecutableURL: brewURL)
        let process = Process()
        process.executableURL = helperURL
        process.arguments = [SelfUpgradeHandoffDefaults.specPathArgument, specURL.path]
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
        let spec = SelfUpgradeHandoffSpec(
            parentProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            appBundlePath: Bundle.main.bundleURL.path,
            relaunchArguments: relaunchArguments,
            relaunchEnvironment: relaunchEnvironment,
            brewExecutablePath: brewExecutableURL.path,
            upgradeArguments: BrewCommands.selfUpgrade().arguments,
            upgradeEnvironment: upgradeEnvironment,
            logFilePath: logFileURL.path,
            defaultsSuiteName: Bundle.main.bundleIdentifier ?? SelfUpgradeIdentity.bundleIdentifier,
            noticeKey: SelfUpgradeLaunchNotice(defaultsKeyPrefix: defaultsKeyPrefix).storageKey,
            successValue: SelfUpgradeOutcome.succeeded.rawValue,
            failureValue: SelfUpgradeOutcome.failed.rawValue,
            waitForExitTimeout: SelfUpgradeHandoffDefaults.waitForExitTimeout,
            upgradeTimeout: SelfUpgradeHandoffDefaults.upgradeTimeout,
        )
        let specURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("self-upgrade-handoff-\(UUID().uuidString).json")
        try spec.encoded().write(to: specURL, options: .atomic)
        return specURL
    }
}

private struct SelfUpgradeHelperUnavailable: LocalizedError {
    var errorDescription: String? {
        String(
            localized: "The upgrade helper is missing from this build of the Homebrew app.",
            comment: "Shown when the bundled self-upgrade helper executable cannot be found",
        )
    }
}
