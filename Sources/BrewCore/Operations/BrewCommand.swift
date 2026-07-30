//
//  BrewCommand.swift
//  BrewCore
//

import Foundation

/// A single Homebrew invocation as data: the argument vector plus the kind of operation it represents.
///
/// There is no per-command behaviour — every `brew` invocation runs the same way (spawn, stream, check exit),
/// so the run algorithm lives once in ``BrewCommandCenter`` and commands are just values built by
/// ``BrewCommands``. The scheduler derives ``BrewOperationPhase`` from ``operationKind`` and passes
/// ``arguments`` straight to the runner.
public struct BrewCommand: Sendable, Equatable {
    public let operationKind: BrewOperationKind
    public let arguments: [String]

    public init(operationKind: BrewOperationKind, arguments: [String]) {
        self.operationKind = operationKind
        self.arguments = arguments
    }
}
