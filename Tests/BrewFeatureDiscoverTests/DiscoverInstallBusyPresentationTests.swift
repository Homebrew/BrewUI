//
//  DiscoverInstallBusyPresentationTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureDiscover
import Foundation
import Testing

struct DiscoverInstallBusyPresentationTests {
    @Test func `running install shows busy`() {
        #expect(DiscoverInstallBusyPresentation.showsInstallBusy(phase: .running(.installFormula)))
        #expect(DiscoverInstallBusyPresentation.showsInstallBusy(phase: .running(.installCask)))
    }

    @Test func `reconciling install still shows busy`() {
        // Discover never reloads its list, so this is the window the installed badge appears in.
        #expect(DiscoverInstallBusyPresentation.showsInstallBusy(phase: .reconciling(.installFormula)))
    }

    @Test func `idle clears busy`() {
        #expect(!DiscoverInstallBusyPresentation.showsInstallBusy(phase: .idle))
    }

    @Test func `failed clears busy`() {
        let failure = OperationFailure(description: "install failed")
        #expect(!DiscoverInstallBusyPresentation.showsInstallBusy(phase: .failed(reason: failure)))
    }

    @Test func `non-install phases are not install busy`() {
        #expect(!DiscoverInstallBusyPresentation.showsInstallBusy(phase: .running(.upgradeFormula)))
        #expect(!DiscoverInstallBusyPresentation.showsInstallBusy(phase: .reconciling(.uninstallFormula)))
    }
}
