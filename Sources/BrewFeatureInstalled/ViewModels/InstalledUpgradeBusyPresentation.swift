//
//  InstalledUpgradeBusyPresentation.swift
//  Brew
//

import BrewCore
import BrewDesignSystem
import BrewRepositories
import Foundation

/// Derived presentation for "upgrade in progress" chrome when observing ``BrewOperationPhase`` for an installed row.
///
/// ``BrewCommandCenter`` can report ``BrewOperationPhase/idle`` before ``InstalledViewModel`` finishes
/// `refresh()` and pushes an updated ``BrewPackage``; while the snapshot still shows ``BrewPackage/outdated``,
/// keep showing busy state.
///
/// Only upgrade operation kinds are matched; uninstall busy state is handled by ``InstalledUninstallBusyPresentation``.
nonisolated enum InstalledUpgradeBusyPresentation {
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

private nonisolated extension BrewOperationPhase {
    var isRunningUpgrade: Bool {
        switch self {
        case .running(.upgradeFormula), .running(.upgradeCask):
            true
        default:
            false
        }
    }
}
