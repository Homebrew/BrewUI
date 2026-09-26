//
//  InstalledUninstallBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// "Uninstall in progress" chrome for an installed row, held until the inventory drops the row.
enum InstalledUninstallBusyPresentation {
    static func showsUninstallBusy(phase: BrewOperationPhase) -> Bool {
        switch phase.activeKind {
        case .uninstallFormula, .uninstallCask:
            true
        default:
            false
        }
    }
}
