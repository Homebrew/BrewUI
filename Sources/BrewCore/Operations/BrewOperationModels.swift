//
//  BrewOperationModels.swift
//  BrewCore
//

import Foundation

/// Homebrew subprocess work the command center may schedule (extend as features grow).
///
/// The read-only ``doctorRead`` case is the small loosening of the original "mutating only" framing —
/// `brew doctor` is read-only but routing it through the center is what makes its output appear in the
/// bottom console alongside everything else (one source of progress visibility, same plumbing).
public enum BrewOperationKind: String, Hashable, Sendable {
    case installFormula
    case installCask
    case upgradeFormula
    case upgradeCask
    case uninstallFormula
    case uninstallCask
    case doctorFix
    case doctorRead
}

/// Stable identity for in-flight mutating work.
///
/// Most work is package-scoped (install/upgrade/uninstall) — one mutating operation per package at a time, so
/// the canonical ``HomebrewPackageID`` *is* the operation key. Maintenance work (e.g. a `brew doctor` fix such as
/// `brew link a b` or `brew cleanup`) isn't tied to a single package, so it carries its own `token` for identity
/// plus the user-facing `displayCommand` the console renders (it cannot be reconstructed from a package name).
public enum BrewOperationID: Hashable, Identifiable, Sendable {
    case package(HomebrewPackageID)
    case maintenance(token: String, displayCommand: String)

    public var id: Self {
        self
    }

    /// The canonical package identity for ``package`` ids; `nil` for ``maintenance`` ids.
    public var packageID: HomebrewPackageID? {
        guard case let .package(packageID) = self else {
            return nil
        }
        return packageID
    }

    public init(packageID: HomebrewPackageID) {
        self = .package(packageID)
    }
}

/// Visibility for UI and tests — mutually exclusive with “absent” represented by ``BrewCommandCenter/phase(for:)``
/// returning ``BrewOperationPhase/idle`` when the center has no record for that id.
public enum BrewOperationPhase: Equatable, Sendable {
    case idle
    case running(BrewOperationKind)
    case failed(reason: OperationFailure)
}
