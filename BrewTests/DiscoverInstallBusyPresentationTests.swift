//
//  DiscoverInstallBusyPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct DiscoverInstallBusyPresentationTests {
    @Test func `running install phase shows busy regardless of awaiting flag`() {
        #expect(
            DiscoverInstallBusyPresentation.showsInstallBusy(
                phase: .running(.installFormula),
                awaitingResolution: false,
                isInstalled: false,
            ),
        )
        #expect(
            DiscoverInstallBusyPresentation.showsInstallBusy(
                phase: .running(.installCask),
                awaitingResolution: false,
                isInstalled: true,
            ),
        )
    }

    @Test func `awaiting resolution stays busy until installed is observed`() {
        #expect(
            DiscoverInstallBusyPresentation.showsInstallBusy(
                phase: .idle,
                awaitingResolution: true,
                isInstalled: false,
            ),
        )
    }

    @Test func `awaiting resolution clears once installed is observed`() {
        #expect(
            !DiscoverInstallBusyPresentation.showsInstallBusy(
                phase: .idle,
                awaitingResolution: true,
                isInstalled: true,
            ),
        )
    }

    @Test func `idle without awaiting is not busy`() {
        #expect(
            !DiscoverInstallBusyPresentation.showsInstallBusy(
                phase: .idle,
                awaitingResolution: false,
                isInstalled: false,
            ),
        )
    }

    @Test func `non-install running phase is not install busy`() {
        #expect(
            !DiscoverInstallBusyPresentation.showsInstallBusy(
                phase: .running(.upgradeFormula),
                awaitingResolution: false,
                isInstalled: false,
            ),
        )
    }
}
