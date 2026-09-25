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

public extension BrewCommand {
    /// The literal a person would type — `"brew "` followed by shell-quoted ``arguments``. Maintenance
    /// operations carry this into their ``BrewOperationID``, so the console renders a command that can be
    /// pasted back into a shell without changing the argv boundaries.
    var displayCommand: String {
        "brew " + arguments.map(Self.shellQuoted).joined(separator: " ")
    }

    private static let shellSafeCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "_@%+=:,./-"),
    )

    private static func shellQuoted(_ argument: String) -> String {
        guard !argument.isEmpty, argument.unicodeScalars.allSatisfy(shellSafeCharacters.contains) else {
            return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        return argument
    }
}
