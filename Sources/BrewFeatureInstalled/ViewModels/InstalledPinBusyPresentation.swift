//
//  InstalledPinBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// Derived presentation for pin/unpin busy chrome when observing ``BrewOperationPhase``.
///
/// ``BrewCommandCenter`` can report ``BrewOperationPhase/idle`` before inventory refresh flips
/// ``InstalledBrewPackage/pinned``. Hold busy through that gap so the control does not flash back
/// to the pre-mutation title. The latch releases when:
/// - The phase transitions to ``BrewOperationPhase/failed(reason:)``, or
/// - ``InstalledListRowViewModel/update(package:)`` / ``InstalledPackageDetailViewModel/update(package:)``
///   resets `operationPhase` after the catalog refresh propagates.
enum InstalledPinBusyPresentation {
    static func showsPinBusy(
        oldPhase: BrewOperationPhase,
        newPhase: BrewOperationPhase,
        isPackagePinned: Bool,
    ) -> Bool {
        if newPhase.isRunningPin {
            return true
        }
        if oldPhase.isRunningPin, case .idle = newPhase, !isPackagePinned {
            return true
        }
        return false
    }

    static func showsUnpinBusy(
        oldPhase: BrewOperationPhase,
        newPhase: BrewOperationPhase,
        isPackagePinned: Bool,
    ) -> Bool {
        if newPhase.isRunningUnpin {
            return true
        }
        if oldPhase.isRunningUnpin, case .idle = newPhase, isPackagePinned {
            return true
        }
        return false
    }
}

private extension BrewOperationPhase {
    var isRunningPin: Bool {
        switch self {
        case .running(.pinFormula), .running(.pinCask):
            true
        default:
            false
        }
    }

    var isRunningUnpin: Bool {
        switch self {
        case .running(.unpinFormula), .running(.unpinCask):
            true
        default:
            false
        }
    }
}
