//
//  UserDefaultsSelfUpdatePreferencesTests.swift
//  BrewTests
//

@testable import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct UserDefaultsSelfUpdatePreferencesTests {
    /// Isolated `UserDefaults` per test so persistence round-trips don't leak across the suite.
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.selfUpdate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    @Test func `nothing is dismissed by default`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(UserDefaultsSelfUpdatePreferences(defaults: defaults).dismissedVersion == nil)
    }

    @Test func `dismissed version persists across instances`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpdatePreferences(defaults: defaults).dismissedVersion = "1.5.0"

        let reloaded = UserDefaultsSelfUpdatePreferences(defaults: defaults)
        #expect(reloaded.dismissedVersion == "1.5.0")
    }

    @Test func `clearing dismissed version removes it from storage`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = UserDefaultsSelfUpdatePreferences(defaults: defaults)
        prefs.dismissedVersion = "1.5.0"
        prefs.dismissedVersion = nil

        #expect(defaults.string(forKey: "selfUpdate.dismissedVersion") == nil)
        #expect(UserDefaultsSelfUpdatePreferences(defaults: defaults).dismissedVersion == nil)
    }

    /// Existing installs keep their dismissal: the default prefix must reproduce the original key name.
    @Test func `default prefix writes the historical key`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpdatePreferences(defaults: defaults).dismissedVersion = "1.5.0"

        #expect(defaults.string(forKey: "selfUpdate.dismissedVersion") == "1.5.0")
    }

    /// A prefixed run must not write through to the real key.
    @Test func `a prefixed instance leaves the unprefixed key untouched`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefixed = UserDefaultsSelfUpdatePreferences(defaults: defaults, defaultsKeyPrefix: "UITesting.selfUpdate")
        prefixed.dismissedVersion = "1.5.0"

        #expect(defaults.string(forKey: "UITesting.selfUpdate.dismissedVersion") == "1.5.0")
        #expect(defaults.object(forKey: "selfUpdate.dismissedVersion") == nil)
        #expect(UserDefaultsSelfUpdatePreferences(defaults: defaults).dismissedVersion == nil)
    }

    /// The reverse: a real install's dismissal must not seed a prefixed run.
    @Test func `an unprefixed instance is invisible to a prefixed one`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpdatePreferences(defaults: defaults).dismissedVersion = "1.5.0"

        let prefixed = UserDefaultsSelfUpdatePreferences(defaults: defaults, defaultsKeyPrefix: "UITesting.selfUpdate")
        #expect(prefixed.dismissedVersion == nil)
    }

    @Test func `distinct prefixes keep separate values`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsSelfUpdatePreferences(defaults: defaults, defaultsKeyPrefix: "A").dismissedVersion = "1.0.0"
        UserDefaultsSelfUpdatePreferences(defaults: defaults, defaultsKeyPrefix: "B").dismissedVersion = "2.0.0"

        #expect(UserDefaultsSelfUpdatePreferences(defaults: defaults, defaultsKeyPrefix: "A").dismissedVersion == "1.0.0")
        #expect(UserDefaultsSelfUpdatePreferences(defaults: defaults, defaultsKeyPrefix: "B").dismissedVersion == "2.0.0")
    }
}
