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
    /// Asked before quitting: terminating would kill the `brew` an install is streaming through.
    /// `brew doctor` is exempt — it changes nothing, and it runs long enough to block every upgrade.
    let commandCenter: any BrewCommandCenter
    let usesLoginShell: Bool
    let defaultsKeyPrefix: String
    /// Carried across the relaunch so a UI-test run comes back still pointed at its fixtures.
    let relaunchArguments: [String]
    let relaunchEnvironment: [String: String]
    let upgradeEnvironment: [String: String]
    let logFileURL: URL

    func performUpgrade() async throws {
        let mutating = await commandCenter.runningPhases().values.contains { phase in
            guard case let .running(kind) = phase else {
                return false
            }
            return kind.isMutating
        }
        guard !mutating else {
            throw SelfUpgradeBlockedByRunningOperation()
        }
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
            usesLoginShell: usesLoginShell,
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

private struct SelfUpgradeBlockedByRunningOperation: LocalizedError {
    var errorDescription: String? {
        String(
            localized: "Wait for the running Homebrew command to finish, then upgrade the Homebrew app.",
            comment: "Shown when the self-upgrade is attempted while another brew command is still running",
        )
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
