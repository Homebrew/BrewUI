//
//  BrewOperationReconciling.swift
//  BrewCore
//

import Foundation

/// Brings cached state back in line with the world a mutating `brew` command just changed.
///
/// Awaited by the command center between the subprocess exiting and the terminal phase being
/// published, which is what makes ``BrewOperationPhase/reconciling(_:)`` a phase rather than a hint.
public protocol BrewOperationReconciling: AnyObject, Sendable {
    /// Non-throwing: a failed reconcile still has to end the operation, or busy chrome never comes down.
    /// The implementation surfaces its own failure.
    func reconcile() async
}
