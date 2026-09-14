/*
 * [INPUT]: 依赖交接协议、命令中心与独立升级 helper
 * [OUTPUT]: 启动升级 helper 或返回类型化交接错误
 * [POS]: 应用级进程交接实现，不在错误抛出时解析语言
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
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
    /// Resolved here so a missing `brew` stops the handoff instead of quitting into a helper that cannot work.
    let brewExecutableURL: @MainActor () throws -> URL
    /// Asked before quitting: terminating would kill the `brew` an install is streaming through.
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
            throw SelfUpgradeHandoffError.operationRunning
        }
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/HomebrewUpgradeHelper")
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw SelfUpgradeHandoffError.helperUnavailable
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
