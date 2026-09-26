//
//  InstalledUpgradeBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// "Upgrade in progress" chrome for an installed row, individual or a covering "Upgrade All"
/// (``BrewOperationKind/upgradeAll``), held until the refreshed inventory lands.
enum InstalledUpgradeBusyPresentation {
    static func showsUpgradeBusy(phase: BrewOperationPhase) -> Bool {
        switch phase.activeKind {
        case .upgradeFormula, .upgradeCask, .upgradeAll:
            true
        default:
            false
        }
    }
}
