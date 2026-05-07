//
//  InstalledListRowViewModel.swift
//  Brew
//

import Foundation
import Observation

/// Per-row `$Observable` state for the installed list — subscribes to
/// ``BrewCommandCenter/phaseChanges(for:)`` so upgrade spinners do not churn the parent
/// ``InstalledViewModel``.
@Observable
@MainActor
final class InstalledListRowViewModel {
    private(set) var upgradeOperationPhase: BrewOperationPhase = .idle
    private let brewCommandCenter: BrewCommandCenter

    var showsUpgradeBusy: Bool {
        if case .running = upgradeOperationPhase {
            return true
        }
        return false
    }

    init(brewCommandCenter: BrewCommandCenter) {
        self.brewCommandCenter = brewCommandCenter
    }

    /// Subscribe until the SwiftUI `.task` that calls this is cancelled (row leaves the list or is torn down).
    func observeRowUpdates(for row: InstalledPackageRow) async {
        let operationID = BrewOperationID(row: row)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            upgradeOperationPhase = phase
        }
    }
}
