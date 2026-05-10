//
//  InstalledUpgradeBusyPresentation.swift
//  Brew
//

import Foundation

/// Derived presentation for “upgrade in progress” chrome when observing ``BrewOperationPhase`` for an installed row.
///
/// ``BrewCommandCenter`` can report ``BrewOperationPhase/idle`` before ``InstalledViewModel`` finishes
/// `refresh()` and pushes an updated ``BrewPackage``; while the snapshot still shows ``BrewPackage/outdated``,
/// keep showing busy state.
enum InstalledUpgradeBusyPresentation {
    static func showsUpgradeBusy(
        oldPhase: BrewOperationPhase,
        newPhase: BrewOperationPhase,
        isPackageOutdated: Bool,
    ) -> Bool {
        if case .running = newPhase {
            return true
        }
        if case .running = oldPhase, case .idle = newPhase, isPackageOutdated {
            return true
        }
        return false
    }
}
