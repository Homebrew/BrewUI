//
//  UpgradeHelper.swift
//  HomebrewUpgradeHelper
//

import AppKit
import BrewSelfUpgradeContract
import BrewSelfUpgradeHelperCore
import Foundation

/// An app cannot replace its own bundle while running, so the helper does it: wait for exit, then upgrade,
/// then relaunch. ``SelfUpgradeHelperRun`` owns that order; this supplies the real effects.
struct UpgradeHelper {
    let spec: SelfUpgradeHandoffSpec
    let log: SelfUpgradeLog

    func run() async {
        log.begin()
        defer { log.end() }

        await SelfUpgradeHelperRun(
            waitForExitTimeout: spec.waitForExitTimeout,
            effects: SelfUpgradeHelperRun.Effects(
                isAppRunning: { isAppRunning() },
                upgrade: { await performUpgrade() },
                recordOutcome: { record(succeeded: $0) },
                relaunchApp: { relaunchApp() },
            ),
            log: { log.write($0) },
        ).run()
    }

    // MARK: Wait

    /// Polls because the helper is not the app's child, so it cannot wait on it.
    private func isAppRunning() -> Bool {
        guard kill(spec.parentProcessIdentifier, 0) != 0 else {
            return true
        }
        // ESRCH: no such process. Anything else (EPERM) means it is alive and not ours to signal.
        return errno != ESRCH
    }

    // MARK: Upgrade

    private func performUpgrade() async -> Bool {
        log.write("running \(spec.brewExecutablePath) \(spec.upgradeArguments.joined(separator: " "))")
        let runner = SelfUpgradeRunner(
            usesLoginShell: spec.usesLoginShell,
            transcriptSink: { line in log.write(line) },
        )
        let outcome = await runner.run(
            executablePath: spec.brewExecutablePath,
            arguments: spec.upgradeArguments,
            environment: spec.upgradeEnvironment,
            timeout: spec.upgradeTimeout,
        )
        log.write(outcome.detail)
        return outcome.succeeded
    }

    // MARK: Report

    /// The app's suite by name: `UserDefaults.standard` here is the helper's own domain.
    private func record(succeeded: Bool) {
        guard let defaults = UserDefaults(suiteName: spec.defaultsSuiteName) else {
            log.write("could not open defaults suite \(spec.defaultsSuiteName); the app will not acknowledge this run")
            return
        }
        defaults.set(succeeded ? spec.successValue : spec.failureValue, forKey: spec.noticeKey)
    }

    // MARK: Relaunch

    private func relaunchApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = spec.relaunchArguments
        configuration.environment = spec.relaunchEnvironment
        configuration.createsNewApplicationInstance = true
        configuration.activates = true

        let bundleURL = URL(fileURLWithPath: spec.appBundlePath)
        let finished = DispatchSemaphore(value: 0)
        let log = log
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if let error {
                log.write("relaunch failed: \(error.localizedDescription)")
            }
            finished.signal()
        }
        // The helper must not exit before the open request has been serviced, or the app never comes back.
        _ = finished.wait(timeout: .now() + 30)
    }
}
