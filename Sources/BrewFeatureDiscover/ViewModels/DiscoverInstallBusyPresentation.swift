//
//  DiscoverInstallBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// "Install in progress" chrome for a Discover row, held through the reconcile that lands the badge.
enum DiscoverInstallBusyPresentation {
    static func showsInstallBusy(phase: BrewOperationPhase) -> Bool {
        switch phase.activeKind {
        case .installFormula, .installCask:
            true
        default:
            false
        }
    }
}
