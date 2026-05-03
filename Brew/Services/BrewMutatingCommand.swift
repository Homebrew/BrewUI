//
//  BrewMutatingCommand.swift
//  Brew
//

import Foundation

/// One schedulable unit of mutating Homebrew work (command pattern); implemented by small `Sendable` types with `run(in:)`.
protocol BrewMutatingCommand: Sendable {
    /// Kind of mutating work — drives ``BrewOperationPhase/running(_:)`` when this command is scheduled.
    nonisolated var operationKind: BrewOperationKind { get }

    func run(in context: BrewCommandExecutionContext) async throws
}
