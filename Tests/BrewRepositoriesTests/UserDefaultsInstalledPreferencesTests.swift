//
//  UserDefaultsInstalledPreferencesTests.swift
//  BrewTests
//

@testable import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct UserDefaultsInstalledPreferencesTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.installed.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    @Test func `dependencies are shown by default`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(UserDefaultsInstalledPreferences(defaults: defaults).hideDependencies == false)
    }

    @Test func `hide dependencies persists across instances`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsInstalledPreferences(defaults: defaults).hideDependencies = true

        #expect(UserDefaultsInstalledPreferences(defaults: defaults).hideDependencies == true)
    }

    @Test func `turning hide dependencies back off persists`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = UserDefaultsInstalledPreferences(defaults: defaults)
        prefs.hideDependencies = true
        prefs.hideDependencies = false

        #expect(UserDefaultsInstalledPreferences(defaults: defaults).hideDependencies == false)
    }

    @Test func `default prefix writes the installed key`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsInstalledPreferences(defaults: defaults).hideDependencies = true

        #expect(defaults.bool(forKey: "installed.hideDependencies") == true)
    }

    @Test func `custom prefix isolates the key`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsInstalledPreferences(defaults: defaults, defaultsKeyPrefix: "UITesting.installed")
            .hideDependencies = true

        #expect(defaults.bool(forKey: "UITesting.installed.hideDependencies") == true)
        #expect(defaults.object(forKey: "installed.hideDependencies") == nil)
    }
}
