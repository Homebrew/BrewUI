//
//  SelfUpdateHandoffSpec.swift
//  BrewSelfUpdateContract
//

import Foundation

/// Everything the update helper needs, as JSON.
///
/// It travels as a file path rather than argv: a UI-test relaunch environment carries the whole fixture tree
/// and would put argv over `ARG_MAX`.
public struct SelfUpdateHandoffSpec: Codable, Sendable, Equatable {
    public let parentProcessIdentifier: Int32
    public let appBundlePath: String
    /// Empty in production; under `-uiTesting` these carry the test's launch flags and fixture payload.
    public let relaunchArguments: [String]
    public let relaunchEnvironment: [String: String]
    /// Resolved by the app, which already knows where `brew` is — and under `-uiTesting` knows it is the
    /// fake one. The helper does no probing of its own: guessing a prefix here would upgrade from the wrong
    /// Homebrew, and the app can refuse the handoff instead of quitting into a helper that cannot work.
    public let brewExecutablePath: String
    /// `["upgrade", "--cask", "homebrew-app"]`, built by `BrewCommands.selfUpgrade()` so the argv the helper
    /// runs is the same value the detail pane displays.
    public let upgradeArguments: [String]
    /// Empty in production. Under `-uiTesting` this points the fake `brew` at the fixture tree, which the
    /// helper cannot inherit: it is spawned by the app, but outlives it.
    public let upgradeEnvironment: [String: String]
    /// The upgrade's transcript. The app is not running while it happens, so without a file a failure has
    /// nowhere to be reported from.
    public let logFilePath: String
    /// Named explicitly: the helper's own `UserDefaults.standard` is a different domain.
    public let defaultsSuiteName: String
    public let noticeKey: String
    /// Strings rather than a ``SelfUpdateOutcome``, so the helper needs no shared enum.
    public let successValue: String
    public let failureValue: String
    public let waitForExitTimeout: TimeInterval
    public let upgradeTimeout: TimeInterval
    /// When set, the helper sleeps for this long instead of updating. `nil` performs the real upgrade.
    public let simulatedUpgradeDuration: TimeInterval?

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
        simulatedUpgradeDuration: TimeInterval?,
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
        self.simulatedUpgradeDuration = simulatedUpgradeDuration
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> SelfUpdateHandoffSpec {
        try JSONDecoder().decode(SelfUpdateHandoffSpec.self, from: data)
    }
}

public enum SelfUpdateHandoffDefaults {
    /// Long enough for a busy app to finish `applicationWillTerminate`.
    public static let waitForExitTimeout: TimeInterval = 30

    /// A cask download on a slow connection is the long pole here.
    public static let upgradeTimeout: TimeInterval = 600

    /// Long enough to see the app quit and come back, short enough for a UI test to wait on.
    public static let simulatedUpgradeDuration: TimeInterval = 2

    public static let specPathArgument = "--spec"

    /// Alongside Homebrew's own logs, and readable without a running app — which is the point, since the
    /// upgrade happens while the app is gone.
    public static func productionLogFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Logs/Homebrew", isDirectory: true)
            .appendingPathComponent("self-update.log")
    }
}
