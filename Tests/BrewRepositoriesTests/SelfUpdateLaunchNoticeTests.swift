//
//  SelfUpdateLaunchNoticeTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewRepositories
import Foundation
import Testing

struct SelfUpdateLaunchNoticeTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.selfUpdateNotice.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func `consume is nil when nothing was marked`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(SelfUpdateLaunchNotice(defaults: defaults).consume() == nil)
    }

    @Test(arguments: SelfUpdateOutcome.allCases)
    func `mark then consume returns the outcome exactly once`(outcome: SelfUpdateOutcome) {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let notice = SelfUpdateLaunchNotice(defaults: defaults)
        notice.mark(outcome)

        #expect(notice.consume() == outcome)
        #expect(notice.consume() == nil)
    }

    @Test func `the outcome survives across notice instances until consumed`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        SelfUpdateLaunchNotice(defaults: defaults).mark(.succeeded)
        // A freshly relaunched app builds a new notice over the same defaults.
        #expect(SelfUpdateLaunchNotice(defaults: defaults).consume() == .succeeded)
    }

    @Test func `default prefix writes the historical key namespace`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(SelfUpdateLaunchNotice(defaults: defaults).storageKey == "selfUpdate.lastUpdateOutcome")
    }

    @Test func `a prefixed notice is invisible to an unprefixed one`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefixed = SelfUpdateLaunchNotice(defaults: defaults, defaultsKeyPrefix: "UITesting.selfUpdate")
        prefixed.mark(.succeeded)

        #expect(defaults.object(forKey: "selfUpdate.lastUpdateOutcome") == nil)
        #expect(SelfUpdateLaunchNotice(defaults: defaults).consume() == nil)
        // The prefixed one still has it — the unprefixed read must not have consumed it.
        #expect(prefixed.consume() == .succeeded)
    }

    @Test func `an unrecognised outcome is consumed as success`() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let notice = SelfUpdateLaunchNotice(defaults: defaults)
        defaults.set("rolledBack", forKey: notice.storageKey)

        #expect(notice.consume() == .succeeded)
        #expect(notice.consume() == nil)
    }
}
