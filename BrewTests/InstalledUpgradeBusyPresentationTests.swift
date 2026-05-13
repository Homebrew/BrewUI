//
//  InstalledUpgradeBusyPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledUpgradeBusyPresentationTests {
    @Test func `running phase shows busy regardless of outdated flag`() {
        #expect(
            InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: .idle,
                newPhase: .running(.upgradeFormula),
                isPackageOutdated: false,
            ),
        )
        #expect(
            InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: .idle,
                newPhase: .running(.upgradeFormula),
                isPackageOutdated: true,
            ),
        )
    }

    @Test func `running to idle stays busy while snapshot still outdated`() {
        #expect(
            InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: .running(.upgradeCask),
                newPhase: .idle,
                isPackageOutdated: true,
            ),
        )
    }

    @Test func `running to idle clears busy once snapshot is up to date`() {
        #expect(
            !InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: .running(.upgradeFormula),
                newPhase: .idle,
                isPackageOutdated: false,
            ),
        )
    }

    @Test func `idle transition without prior running does not imply busy`() {
        #expect(
            !InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: .idle,
                newPhase: .idle,
                isPackageOutdated: true,
            ),
        )
    }

    @Test func `running to failed clears busy`() {
        let failure = OperationFailure(userFacingMessage: "upgrade failed")
        #expect(
            !InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: .running(.upgradeFormula),
                newPhase: .failed(reason: failure),
                isPackageOutdated: true,
            ),
        )
    }
}
