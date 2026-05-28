//
//  BrewOperationModels.swift
//  Brew
//

import Foundation

/// Mutating Homebrew work the command center may schedule (extend as features grow).
nonisolated enum BrewOperationKind: String, Hashable {
    case installFormula
    case installCask
    case upgradeFormula
    case upgradeCask
    case uninstallFormula
    case uninstallCask
}

/// Stable identity for in-flight mutating work (e.g. upgrades), backed by the canonical
/// ``HomebrewPackageID``. There is one mutating operation per package at a time, so the package
/// identity *is* the operation key — no stringly-typed `kind:name` encoding to parse.
nonisolated struct BrewOperationID: Hashable, Identifiable {
    let packageID: HomebrewPackageID

    var id: HomebrewPackageID {
        packageID
    }
}

/// Visibility for UI and tests — mutually exclusive with “absent” represented by ``BrewCommandCenter/phase(for:)``
/// returning ``BrewOperationPhase/idle`` when the center has no record for that id.
nonisolated enum BrewOperationPhase: Equatable {
    case idle
    case running(BrewOperationKind)
    case failed(reason: OperationFailure)
}
