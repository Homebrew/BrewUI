//
//  InstalledListRowViewModel.swift
//  Brew
//

import Foundation
import Observation

/// Per-row `$Observable` state for the installed list — subscribes to ``BrewCommandCenter/phaseChanges(for:)`` so upgrade spinners do not churn the parent ``InstalledViewModel``.
/// Row labels and versions are owned locally once initialized so row updates can be patched back into the parent catalog without a full list reload.
@Observable
@MainActor
final class InstalledListRowViewModel {
    private let refreshRow: @MainActor (InstalledPackageRow) async -> InstalledPackageRow?
    private let onRowUpdated: @MainActor (InstalledPackageRow) -> Void

    private(set) var row: InstalledPackageRow
    private(set) var upgradeOperationPhase: BrewOperationPhase = .idle

    var showsUpgradeBusy: Bool {
        if case .running = upgradeOperationPhase {
            return true
        }
        return false
    }

    init(
        row: InstalledPackageRow,
        refreshRow: @escaping @MainActor (InstalledPackageRow) async -> InstalledPackageRow? = { row in row },
        onRowUpdated: @escaping @MainActor (InstalledPackageRow) -> Void = { _ in },
    ) {
        self.row = row
        self.refreshRow = refreshRow
        self.onRowUpdated = onRowUpdated
    }

    /// Builds a row VM with upgrade spinner shown — **SwiftUI previews only** (not for production UI).
    static func previewBusyUpgrade() -> InstalledListRowViewModel {
        let row = InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "Distributed revision control system",
            installedVersion: "v2.45.0",
            updateVersion: "v2.45.1",
        )
        let vm = InstalledListRowViewModel(row: row)
        vm.upgradeOperationPhase = .running(.upgradeFormula)
        return vm
    }

    /// Subscribe until the SwiftUI `.task` that calls this is cancelled (row leaves the list or is torn down).
    func observeRowUpdates(for row: InstalledPackageRow, using brewCommandCenter: any BrewCommandCenter) async {
        let operationID = BrewOperationID(row: row)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        var wasRunning = false
        for await phase in stream {
            upgradeOperationPhase = phase
            switch phase {
            case .idle:
                guard wasRunning else {
                    continue
                }
                wasRunning = false
                await refreshFromRepository()
            case .running:
                wasRunning = true
            case .failed:
                wasRunning = false
            }
        }
    }

    private func refreshFromRepository() async {
        guard let refreshedRow = await refreshRow(row) else {
            return
        }
        row = refreshedRow
        onRowUpdated(refreshedRow)
    }
}
