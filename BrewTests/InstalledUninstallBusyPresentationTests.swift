//
//  InstalledUninstallBusyPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledUninstallBusyPresentationTests {
    @Test func `running uninstall phase shows busy`() {
        #expect(
            InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .idle,
                newPhase: .running(.uninstallFormula),
            ),
        )
        #expect(
            InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .idle,
                newPhase: .running(.uninstallCask),
            ),
        )
    }

    @Test func `running uninstall to idle latches busy`() {
        #expect(
            InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .running(.uninstallFormula),
                newPhase: .idle,
            ),
        )
        #expect(
            InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .running(.uninstallCask),
                newPhase: .idle,
            ),
        )
    }

    @Test func `running uninstall to failed clears busy`() {
        let failure = OperationFailure(userFacingMessage: "uninstall failed")
        #expect(
            !InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .running(.uninstallFormula),
                newPhase: .failed(reason: failure),
            ),
        )
    }

    @Test func `idle to idle does not trigger busy`() {
        #expect(
            !InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .idle,
                newPhase: .idle,
            ),
        )
    }

    @Test func `upgrade running phase does not trigger uninstall busy`() {
        #expect(
            !InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .idle,
                newPhase: .running(.upgradeFormula),
            ),
        )
        #expect(
            !InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: .idle,
                newPhase: .running(.upgradeCask),
            ),
        )
    }
}
