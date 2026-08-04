//
//  InstalledUpgradeBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// "Upgrade in progress" chrome for an installed row, individual or a covering "Upgrade All"
/// (``BrewOperationKind/upgradeAll``). The command center can report `idle` before the inventory refresh
/// lands, so busy is held through `running → idle` while the snapshot is still outdated.
enum InstalledUpgradeBusyPresentation {
    static func showsUpgradeBusy(
        oldPhase: BrewOperationPhase,
        newPhase: BrewOperationPhase,
        isPackageOutdated: Bool,
    ) -> Bool {
        if newPhase.isRunningUpgrade {
            return true
        }
        if oldPhase.isRunningUpgrade, case .idle = newPhase, isPackageOutdated {
            return true
        }
        return false
    }
}

private extension BrewOperationPhase {
    var isRunningUpgrade: Bool {
        switch self {
        case .running(.upgradeFormula), .running(.upgradeCask), .running(.upgradeAll):
            true
        default:
            false
        }
    }
}
