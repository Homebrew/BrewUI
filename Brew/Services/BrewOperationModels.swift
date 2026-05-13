//
//  BrewOperationModels.swift
//  Brew
//

import Foundation

/// Mutating Homebrew work the command center may schedule (extend as features grow).
nonisolated enum BrewOperationKind: String, Hashable {
    case upgradeFormula
    case upgradeCask
}

/// Stable opaque identity for in-flight mutating work (e.g. upgrades). Conventionally `formula:<name>` or `cask:<name>` to align with Homebrew package identity strings — see ``BrewOperationID`` helpers in the Models layer.
nonisolated struct BrewOperationID: Hashable, Identifiable {
    var id: String {
        rawValue
    }

    let rawValue: String
}

/// Visibility for UI and tests — mutually exclusive with “absent” represented by ``BrewCommandCenter/phase(for:)``
/// returning ``BrewOperationPhase/idle`` when the center has no record for that id.
nonisolated enum BrewOperationPhase: Equatable {
    case idle
    case running(BrewOperationKind)
    case failed(reason: OperationFailure)
}
