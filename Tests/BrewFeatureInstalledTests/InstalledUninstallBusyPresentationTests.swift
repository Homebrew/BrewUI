//
//  InstalledUninstallBusyPresentationTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureInstalled
import Foundation
import Testing

struct InstalledUninstallBusyPresentationTests {
    @Test func `running uninstall shows busy`() {
        #expect(InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .running(.uninstallFormula)))
        #expect(InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .running(.uninstallCask)))
    }

    @Test func `reconciling uninstall still shows busy`() {
        // The row is still in the list until the refreshed inventory drops it.
        #expect(InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .reconciling(.uninstallFormula)))
    }

    @Test func `idle clears busy`() {
        #expect(!InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .idle))
    }

    @Test func `failed clears busy`() {
        let failure = OperationFailure(description: "uninstall failed")
        #expect(!InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .failed(reason: failure)))
    }

    @Test func `upgrade phases do not show uninstall busy`() {
        #expect(!InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .running(.upgradeFormula)))
        #expect(!InstalledUninstallBusyPresentation.showsUninstallBusy(phase: .reconciling(.upgradeCask)))
    }
}
