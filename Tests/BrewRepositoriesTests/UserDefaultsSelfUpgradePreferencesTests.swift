//
//  UserDefaultsSelfUpgradePreferencesTests.swift
//  BrewTests
//

@testable import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct UserDefaultsSelfUpgradePreferencesTests {
    /// Isolated `UserDefaults` per test so persistence round-trips don't leak across the suite.
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.selfUpgrade.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    @Test func `nothing is dismissed by default`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(UserDefaultsSelfUpgradePreferences(defaults: defaults).dismissedVersion == nil)
    }

    @Test func `dismissed version persists across instances`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpgradePreferences(defaults: defaults).dismissedVersion = "1.5.0"

        let reloaded = UserDefaultsSelfUpgradePreferences(defaults: defaults)
        #expect(reloaded.dismissedVersion == "1.5.0")
    }

    @Test func `clearing dismissed version removes it from storage`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = UserDefaultsSelfUpgradePreferences(defaults: defaults)
        prefs.dismissedVersion = "1.5.0"
        prefs.dismissedVersion = nil

        #expect(defaults.string(forKey: "selfUpgrade.dismissedVersion") == nil)
        #expect(UserDefaultsSelfUpgradePreferences(defaults: defaults).dismissedVersion == nil)
    }

    /// Existing installs keep their dismissal: the default prefix must reproduce the original key name.
    @Test func `default prefix writes the historical key`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpgradePreferences(defaults: defaults).dismissedVersion = "1.5.0"

        #expect(defaults.string(forKey: "selfUpgrade.dismissedVersion") == "1.5.0")
    }

    /// A prefixed run must not write through to the real key.
    @Test func `a prefixed instance leaves the unprefixed key untouched`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefixed = UserDefaultsSelfUpgradePreferences(defaults: defaults, defaultsKeyPrefix: "UITesting.selfUpgrade")
        prefixed.dismissedVersion = "1.5.0"

        #expect(defaults.string(forKey: "UITesting.selfUpgrade.dismissedVersion") == "1.5.0")
        #expect(defaults.object(forKey: "selfUpgrade.dismissedVersion") == nil)
        #expect(UserDefaultsSelfUpgradePreferences(defaults: defaults).dismissedVersion == nil)
    }

    /// The reverse: a real install's dismissal must not seed a prefixed run.
    @Test func `an unprefixed instance is invisible to a prefixed one`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpgradePreferences(defaults: defaults).dismissedVersion = "1.5.0"

        let prefixed = UserDefaultsSelfUpgradePreferences(defaults: defaults, defaultsKeyPrefix: "UITesting.selfUpgrade")
        #expect(prefixed.dismissedVersion == nil)
    }

    @Test func `distinct prefixes keep separate values`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpgradePreferences(defaults: defaults, defaultsKeyPrefix: "A").dismissedVersion = "1.0.0"
        UserDefaultsSelfUpgradePreferences(defaults: defaults, defaultsKeyPrefix: "B").dismissedVersion = "2.0.0"

        #expect(UserDefaultsSelfUpgradePreferences(defaults: defaults, defaultsKeyPrefix: "A").dismissedVersion == "1.0.0")
        #expect(UserDefaultsSelfUpgradePreferences(defaults: defaults, defaultsKeyPrefix: "B").dismissedVersion == "2.0.0")
    }
}
