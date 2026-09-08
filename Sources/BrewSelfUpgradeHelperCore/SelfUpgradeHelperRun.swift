//
//  SelfUpgradeHelperRun.swift
//  BrewSelfUpgradeHelperCore
//

import Foundation

/// The helper's order of work — wait for the app to exit, upgrade, record, relaunch — with the AppKit and
/// `UserDefaults` calls behind ``Effects`` so the sequence itself can be tested.
public struct SelfUpgradeHelperRun: Sendable {
    public enum Result: Equatable, Sendable {
        case relaunched(upgraded: Bool)
        /// The app outlived the wait, so it was left alone: relaunching would put a second copy of a
        /// still-running app on screen, and there is no upgrade to acknowledge.
        case abandoned
    }

    public struct Effects: Sendable {
        public let isAppRunning: @Sendable () -> Bool
        public let upgrade: @Sendable () async -> Bool
        public let recordOutcome: @Sendable (Bool) -> Void
        public let relaunchApp: @Sendable () async -> Void

        public init(
            isAppRunning: @escaping @Sendable () -> Bool,
            upgrade: @escaping @Sendable () async -> Bool,
            recordOutcome: @escaping @Sendable (Bool) -> Void,
            relaunchApp: @escaping @Sendable () async -> Void,
        ) {
            self.isAppRunning = isAppRunning
            self.upgrade = upgrade
            self.recordOutcome = recordOutcome
            self.relaunchApp = relaunchApp
        }
    }

    public static let defaultPollInterval = Duration.milliseconds(100)

    private let waitForExitTimeout: TimeInterval
    private let pollInterval: Duration
    private let effects: Effects
    private let log: @Sendable (String) -> Void
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async -> Void

    public init(
        waitForExitTimeout: TimeInterval,
        pollInterval: Duration = Self.defaultPollInterval,
        effects: Effects,
        log: @escaping @Sendable (String) -> Void = { _ in },
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) },
    ) {
        self.waitForExitTimeout = waitForExitTimeout
        self.pollInterval = pollInterval
        self.effects = effects
        self.log = log
        self.now = now
        self.sleep = sleep
    }

    @discardableResult
    public func run() async -> Result {
        guard await waitForAppToExit() else {
            log("timed out after \(waitForExitTimeout)s waiting for the app to exit; leaving it running")
            return .abandoned
        }
        let upgraded = await effects.upgrade()
        effects.recordOutcome(upgraded)
        await effects.relaunchApp()
        return .relaunched(upgraded: upgraded)
    }

    private func waitForAppToExit() async -> Bool {
        let deadline = now().addingTimeInterval(waitForExitTimeout)
        while now() < deadline {
            if !effects.isAppRunning() {
                return true
            }
            await sleep(pollInterval)
        }
        // One last look: the final sleep can carry the clock past the deadline while the app was quitting.
        return !effects.isAppRunning()
    }
}
