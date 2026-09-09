//
//  SelfUpgradeLaunchNoticeTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewRepositories
import Foundation
import Testing

struct SelfUpgradeLaunchNoticeTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.selfUpgradeNotice.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func `consume is nil when nothing was marked`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(SelfUpgradeLaunchNotice(defaults: defaults).consume() == nil)
    }

    @Test(arguments: SelfUpgradeOutcome.allCases)
    func `mark then consume returns the outcome exactly once`(outcome: SelfUpgradeOutcome) {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let notice = SelfUpgradeLaunchNotice(defaults: defaults)
        notice.mark(outcome)

        #expect(notice.consume() == outcome)
        #expect(notice.consume() == nil)
    }

    @Test func `the outcome survives across notice instances until consumed`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        SelfUpgradeLaunchNotice(defaults: defaults).mark(.succeeded)
        // A freshly relaunched app builds a new notice over the same defaults.
        #expect(SelfUpgradeLaunchNotice(defaults: defaults).consume() == .succeeded)
    }

    @Test func `default prefix writes the historical key namespace`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(SelfUpgradeLaunchNotice(defaults: defaults).storageKey == "selfUpgrade.lastUpgradeOutcome")
    }

    @Test func `a prefixed notice is invisible to an unprefixed one`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefixed = SelfUpgradeLaunchNotice(defaults: defaults, defaultsKeyPrefix: "UITesting.selfUpgrade")
        prefixed.mark(.succeeded)

        #expect(defaults.object(forKey: "selfUpgrade.lastUpgradeOutcome") == nil)
        #expect(SelfUpgradeLaunchNotice(defaults: defaults).consume() == nil)
        // The prefixed one still has it — the unprefixed read must not have consumed it.
        #expect(prefixed.consume() == .succeeded)
    }

    @Test func `an unrecognised outcome is consumed as success`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let notice = SelfUpgradeLaunchNotice(defaults: defaults)
        defaults.set("rolledBack", forKey: notice.storageKey)

        #expect(notice.consume() == .succeeded)
        #expect(notice.consume() == nil)
    }
}
