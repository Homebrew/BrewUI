//
//  InstalledUninstallBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// Derived presentation for "uninstall in progress" chrome when observing ``BrewOperationPhase`` for an installed row.
///
/// ``BrewCommandCenter`` can report ``BrewOperationPhase/idle`` before ``InstalledViewModel`` finishes
/// `refresh()` and removes the package from the catalog; while the snapshot still shows the package as
/// installed, keep showing busy state so the UI does not flash back to the normal installed appearance.
///
/// The latch releases when:
/// - The phase transitions to ``BrewOperationPhase/failed(reason:)`` (error is surfaced instead), or
/// - ``InstalledListRowViewModel/update(package:)`` / ``InstalledPackageDetailViewModel/update(package:)``
///   resets `operationPhase` to ``BrewOperationPhase/idle`` after the catalog refresh propagates.
enum InstalledUninstallBusyPresentation {
    static func showsUninstallBusy(
        oldPhase: BrewOperationPhase,
        newPhase: BrewOperationPhase,
    ) -> Bool {
        if newPhase.isRunningUninstall {
            return true
        }
        if oldPhase.isRunningUninstall, case .idle = newPhase {
            return true
        }
        return false
    }
}

private extension BrewOperationPhase {
    var isRunningUninstall: Bool {
        switch self {
        case .running(.uninstallFormula), .running(.uninstallCask):
            true
        default:
            false
        }
    }
}
