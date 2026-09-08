//
//  SelfUpdateHandoffSpecTests.swift
//  BrewTests
//

import BrewSelfUpdateContract
import Foundation
import Testing

/// A field the helper cannot read means the app quits and nothing brings it back.
struct SelfUpdateHandoffSpecTests {
    private func makeSpec(simulatedUpgradeDuration: TimeInterval? = 2) -> SelfUpdateHandoffSpec {
        SelfUpdateHandoffSpec(
            parentProcessIdentifier: 4321,
            appBundlePath: "/Applications/Homebrew.app",
            relaunchArguments: ["-uiTesting", "YES"],
            relaunchEnvironment: ["BREW_UITEST_SCENARIO": "selfUpdateAvailable"],
            brewExecutablePath: "/opt/homebrew/bin/brew",
            upgradeArguments: ["upgrade", "--cask", "homebrew-app"],
            upgradeEnvironment: ["BREW_UITEST_FIXTURES": "/tmp/fixtures"],
            logFilePath: "/tmp/self-update.log",
            defaultsSuiteName: "sh.brew.app",
            noticeKey: "UITesting.selfUpdate.lastUpdateOutcome",
            successValue: "succeeded",
            failureValue: "failed",
            waitForExitTimeout: 30,
            upgradeTimeout: 600,
            simulatedUpgradeDuration: simulatedUpgradeDuration,
        )
    }

    @Test func `a spec survives the round trip intact`() throws {
        let spec = makeSpec()
        #expect(try SelfUpdateHandoffSpec.decoded(from: spec.encoded()) == spec)
    }

    /// `nil` selects the real upgrade, so it must not quietly become a zero-second simulation.
    @Test func `a nil simulated duration round trips as nil`() throws {
        let spec = makeSpec(simulatedUpgradeDuration: nil)
        let decoded = try SelfUpdateHandoffSpec.decoded(from: spec.encoded())

        #expect(decoded.simulatedUpgradeDuration == nil)
        #expect(decoded == spec)
    }

    @Test func `the relaunch environment survives, since a UI-test relaunch depends on it`() throws {
        let spec = makeSpec()
        let decoded = try SelfUpdateHandoffSpec.decoded(from: spec.encoded())

        #expect(decoded.relaunchEnvironment["BREW_UITEST_SCENARIO"] == "selfUpdateAvailable")
        #expect(decoded.relaunchArguments == ["-uiTesting", "YES"])
    }

    /// The helper does no probing of its own, so a dropped path is an upgrade of nothing.
    @Test func `the upgrade invocation survives the round trip`() throws {
        let decoded = try SelfUpdateHandoffSpec.decoded(from: makeSpec().encoded())

        #expect(decoded.brewExecutablePath == "/opt/homebrew/bin/brew")
        #expect(decoded.upgradeArguments == ["upgrade", "--cask", "homebrew-app"])
        #expect(decoded.upgradeEnvironment["BREW_UITEST_FIXTURES"] == "/tmp/fixtures")
        #expect(decoded.logFilePath == "/tmp/self-update.log")
    }

    @Test func `decoding rejects input that is not a spec`() {
        #expect(throws: (any Error).self) {
            try SelfUpdateHandoffSpec.decoded(from: Data("not a spec".utf8))
        }
    }

    /// A wedged app must not hold the helper past the point where someone has relaunched by hand.
    @Test func `the default timeouts are ordered`() {
        #expect(SelfUpdateHandoffDefaults.waitForExitTimeout < SelfUpdateHandoffDefaults.upgradeTimeout)
        #expect(SelfUpdateHandoffDefaults.simulatedUpgradeDuration < SelfUpdateHandoffDefaults.waitForExitTimeout)
    }

    /// Namespaced like every other root the app writes to, and somewhere a user whose app came back at
    /// the old version can be told to look.
    @Test func `the production log sits under the app's own logs directory`() {
        let url = SelfUpdateHandoffDefaults.productionLogFileURL(
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
        )

        #expect(url.path == "/Users/example/Library/Logs/sh.brew.app/self-update.log")
    }

    /// `Logs/Homebrew` is the `brew` CLI's own directory; writing there would put the app's transcript
    /// among logs it does not own.
    @Test func `the production log is not written into Homebrew's own log directory`() {
        let url = SelfUpdateHandoffDefaults.productionLogFileURL(
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
        )

        #expect(!url.path.contains("Logs/Homebrew"))
        #expect(url.deletingLastPathComponent().lastPathComponent == "sh.brew.app")
    }
}
