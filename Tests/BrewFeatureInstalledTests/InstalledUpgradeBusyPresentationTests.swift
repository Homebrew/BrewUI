//
//  InstalledUpgradeBusyPresentationTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureInstalled
import Foundation
import Testing

struct InstalledUpgradeBusyPresentationTests {
    @Test func `running upgrade shows busy`() {
        #expect(InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .running(.upgradeFormula)))
        #expect(InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .running(.upgradeCask)))
    }

    @Test func `reconciling upgrade still shows busy`() {
        // The row would otherwise flash back to "upgrade available" before the snapshot lands.
        #expect(InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .reconciling(.upgradeFormula)))
    }

    @Test func `idle clears busy`() {
        #expect(!InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .idle))
    }

    @Test func `failed clears busy`() {
        let failure = OperationFailure(description: "upgrade failed")
        #expect(!InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .failed(reason: failure)))
    }

    @Test func `bulk upgrade shows busy like an individual upgrade`() {
        // The observer only feeds this method bulk phases that actually cover the package.
        #expect(InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .running(.upgradeAll)))
        #expect(InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .reconciling(.upgradeAll)))
    }

    @Test func `uninstall phases do not show upgrade busy`() {
        #expect(!InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .running(.uninstallFormula)))
        #expect(!InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: .reconciling(.uninstallCask)))
    }
}
