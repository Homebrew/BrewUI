//
//  InstalledListRowViewModel.swift
//  Brew
//

import Foundation
import Observation

/// Per-row `$Observable` state for the installed list — subscribes to ``BrewCommandCenter/phaseChanges(for:)`` so upgrade spinners do not churn the parent ``InstalledViewModel``.
@Observable
@MainActor
final class InstalledListRowViewModel {
    @ObservationIgnored let row: InstalledPackageRow

    private(set) var upgradeOperationPhase: BrewOperationPhase = .idle

    var showsUpgradeBusy: Bool {
        if case .running = upgradeOperationPhase {
            return true
        }
        return false
    }

    init(row: InstalledPackageRow) {
        self.row = row
    }

    /// Builds a row VM with upgrade spinner shown — **SwiftUI previews only** (not for production UI).
    static func previewBusyUpgrade(row: InstalledPackageRow) -> InstalledListRowViewModel {
        let vm = InstalledListRowViewModel(row: row)
        vm.upgradeOperationPhase = .running(.upgradeFormula)
        return vm
    }

    /// Subscribe until the SwiftUI `.task` that calls this is cancelled (row leaves the list or is torn down).
    func observeRowUpdates(using brewCommandCenter: any BrewCommandCenter) async {
        let operationID = BrewOperationID(row: row)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            upgradeOperationPhase = phase
        }
    }
}
