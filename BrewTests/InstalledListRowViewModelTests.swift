//
//  InstalledListRowViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct InstalledListRowViewModelTests {
    @Test func `observeRowUpdates applies first phase from noop center`() async {
        let row = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v1",
        )
        let center = NoopBrewCommandCenter.forTesting()
        let viewModel = InstalledListRowViewModel(row: row)
        #expect(viewModel.upgradeOperationPhase == .idle)

        await viewModel.observeRowUpdates(using: center)

        #expect(viewModel.upgradeOperationPhase == .idle)
    }
}
