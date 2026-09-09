//
//  SelfUpgradeHandoffSpecTests.swift
//  BrewTests
//

import BrewSelfUpgradeContract
import Foundation
import Testing

/// A field the helper cannot read means the app quits and nothing brings it back.
struct SelfUpgradeHandoffSpecTests {
    private func makeSpec() -> SelfUpgradeHandoffSpec {
        SelfUpgradeHandoffSpec(
            parentProcessIdentifier: 4321,
            appBundlePath: "/Applications/Homebrew.app",
            relaunchArguments: ["-uiTesting", "YES"],
            relaunchEnvironment: ["BREW_UITEST_SCENARIO": "selfUpgradeAvailable"],
            brewExecutablePath: "/opt/homebrew/bin/brew",
            upgradeArguments: ["upgrade", "--cask", "homebrew-app"],
            usesLoginShell: true,
            upgradeEnvironment: ["BREW_UITEST_FIXTURES": "/tmp/fixtures"],
            logFilePath: "/tmp/self-upgrade.log",
            defaultsSuiteName: "sh.brew.app",
            noticeKey: "UITesting.selfUpgrade.lastUpgradeOutcome",
            successValue: "succeeded",
            failureValue: "failed",
            waitForExitTimeout: 30,
            upgradeTimeout: 600,
        )
    }

    @Test func `a spec survives the round trip intact`() throws {
        let spec = makeSpec()
        #expect(try SelfUpgradeHandoffSpec.decoded(from: spec.encoded()) == spec)
    }

    @Test func `the relaunch environment survives, since a UI-test relaunch depends on it`() throws {
        let spec = makeSpec()
        let decoded = try SelfUpgradeHandoffSpec.decoded(from: spec.encoded())

        #expect(decoded.relaunchEnvironment["BREW_UITEST_SCENARIO"] == "selfUpgradeAvailable")
        #expect(decoded.relaunchArguments == ["-uiTesting", "YES"])
    }

    /// The helper does no probing of its own, so a dropped path is an upgrade of nothing.
    @Test func `the upgrade invocation survives the round trip`() throws {
        let decoded = try SelfUpgradeHandoffSpec.decoded(from: makeSpec().encoded())

        #expect(decoded.brewExecutablePath == "/opt/homebrew/bin/brew")
        #expect(decoded.upgradeArguments == ["upgrade", "--cask", "homebrew-app"])
        #expect(decoded.upgradeEnvironment["BREW_UITEST_FIXTURES"] == "/tmp/fixtures")
        #expect(decoded.usesLoginShell)
        #expect(decoded.logFilePath == "/tmp/self-upgrade.log")
    }

    @Test func `decoding rejects input that is not a spec`() {
        #expect(throws: (any Error).self) {
            try SelfUpgradeHandoffSpec.decoded(from: Data("not a spec".utf8))
        }
    }

    /// A wedged app must not hold the helper past the point where someone has relaunched by hand.
    @Test func `the default timeouts are ordered`() {
        #expect(SelfUpgradeHandoffDefaults.waitForExitTimeout < SelfUpgradeHandoffDefaults.upgradeTimeout)
    }

    /// Namespaced like every other root the app writes to, and somewhere a user can be told to look.
    @Test func `the production log sits under the app's own logs directory`() {
        let url = SelfUpgradeHandoffDefaults.productionLogFileURL(
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
        )

        #expect(url.path == "/Users/example/Library/Logs/sh.brew.app/self-upgrade.log")
    }

    /// `Logs/Homebrew` is the `brew` CLI's own directory, not the app's to write into.
    @Test func `the production log is not written into Homebrew's own log directory`() {
        let url = SelfUpgradeHandoffDefaults.productionLogFileURL(
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
        )

        #expect(!url.path.contains("Logs/Homebrew"))
        #expect(url.deletingLastPathComponent().lastPathComponent == "sh.brew.app")
    }
}
