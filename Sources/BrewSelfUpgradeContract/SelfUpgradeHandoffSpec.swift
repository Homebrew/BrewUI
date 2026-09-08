//
//  SelfUpgradeHandoffSpec.swift
//  BrewSelfUpgradeContract
//

import Foundation

/// The spec travels as a file path rather than argv: a UI-test relaunch environment carries the whole fixture tree
/// and would put argv over `ARG_MAX`.
public struct SelfUpgradeHandoffSpec: Codable, Sendable, Equatable {
    public let parentProcessIdentifier: Int32
    public let appBundlePath: String
    public let relaunchArguments: [String]
    public let relaunchEnvironment: [String: String]
    /// Resolved by the app, which already knows where `brew` is — and under `-uiTesting` knows it is the
    /// fake one. The helper does no probing of its own: guessing a prefix here would upgrade from the wrong
    /// Homebrew, and the app can refuse the handoff instead of quitting into a helper that cannot work.
    public let brewExecutablePath: String
    /// Built by `BrewCommands.selfUpgrade()`, so the argv the helper runs is what the app displays.
    public let upgradeArguments: [String]
    /// Empty in production. Under `-uiTesting` this points the fake `brew` at the fixture tree, which the
    /// helper cannot inherit: it is spawned by the app, but outlives it.
    public let upgradeEnvironment: [String: String]
    public let logFilePath: String
    /// Named explicitly: the helper's own `UserDefaults.standard` is a different domain.
    public let defaultsSuiteName: String
    public let noticeKey: String
    /// Strings rather than a ``SelfUpgradeOutcome``, so the helper needs no shared enum.
    public let successValue: String
    public let failureValue: String
    public let waitForExitTimeout: TimeInterval
    public let upgradeTimeout: TimeInterval

    public init(
        parentProcessIdentifier: Int32,
        appBundlePath: String,
        relaunchArguments: [String],
        relaunchEnvironment: [String: String],
        brewExecutablePath: String,
        upgradeArguments: [String],
        upgradeEnvironment: [String: String],
        logFilePath: String,
        defaultsSuiteName: String,
        noticeKey: String,
        successValue: String,
        failureValue: String,
        waitForExitTimeout: TimeInterval,
        upgradeTimeout: TimeInterval,
    ) {
        self.parentProcessIdentifier = parentProcessIdentifier
        self.appBundlePath = appBundlePath
        self.relaunchArguments = relaunchArguments
        self.relaunchEnvironment = relaunchEnvironment
        self.brewExecutablePath = brewExecutablePath
        self.upgradeArguments = upgradeArguments
        self.upgradeEnvironment = upgradeEnvironment
        self.logFilePath = logFilePath
        self.defaultsSuiteName = defaultsSuiteName
        self.noticeKey = noticeKey
        self.successValue = successValue
        self.failureValue = failureValue
        self.waitForExitTimeout = waitForExitTimeout
        self.upgradeTimeout = upgradeTimeout
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> SelfUpgradeHandoffSpec {
        try JSONDecoder().decode(SelfUpgradeHandoffSpec.self, from: data)
    }
}

public enum SelfUpgradeHandoffDefaults {
    /// Long enough for a busy app to finish `applicationWillTerminate`.
    public static let waitForExitTimeout: TimeInterval = 30

    /// A cask download on a slow connection is the long pole here.
    public static let upgradeTimeout: TimeInterval = 600

    public static let specPathArgument = "--spec"

    /// Readable without a running app, which is the point — the upgrade happens while the app is gone.
    public static func productionLogFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Logs/sh.brew.app", isDirectory: true)
            .appendingPathComponent("self-upgrade.log")
    }
}
