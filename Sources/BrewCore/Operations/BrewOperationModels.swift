//
//  BrewOperationModels.swift
//  BrewCore
//

import Foundation

/// Mutating Homebrew work the command center may schedule (extend as features grow).
public nonisolated enum BrewOperationKind: String, Hashable, Sendable {
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
public nonisolated struct BrewOperationID: Hashable, Identifiable, Sendable {
    public let packageID: HomebrewPackageID

    public var id: HomebrewPackageID {
        packageID
    }

    public init(packageID: HomebrewPackageID) {
        self.packageID = packageID
    }
}

/// Visibility for UI and tests — mutually exclusive with “absent” represented by ``BrewCommandCenter/phase(for:)``
/// returning ``BrewOperationPhase/idle`` when the center has no record for that id.
public nonisolated enum BrewOperationPhase: Equatable, Sendable {
    case idle
    case running(BrewOperationKind)
    case failed(reason: OperationFailure)
}
