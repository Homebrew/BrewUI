//
//  DiscoverInstallBusyPresentation.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation

/// Derived presentation for "install in progress" chrome on a Discover row.
///
/// The Discover list (search/trending results) is not reloaded when an install completes, so a
/// stored-flag-only approach cannot self-clear the way ``InstalledUpgradeBusyPresentation`` does.
/// Instead, bridge the gap between the operation finishing and the installed badge appearing by
/// reading the observable installed-state: stay busy while the operation is running, and keep busy
/// after it finishes until the package is observed as installed.
enum DiscoverInstallBusyPresentation {
    static func showsInstallBusy(
        phase: BrewOperationPhase,
        awaitingResolution: Bool,
        isInstalled: Bool,
    ) -> Bool {
        if phase.isRunningInstall {
            return true
        }
        return awaitingResolution && !isInstalled
    }
}

extension BrewOperationPhase {
    var isRunningInstall: Bool {
        switch self {
        case .running(.installFormula), .running(.installCask):
            true
        default:
            false
        }
    }
}
