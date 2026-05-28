//
//  CommandJob.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// One brew command's lifecycle as observed by the console UI: identity, phase, streamed output, and final exit code.
///
/// Reuses ``BrewOperationID`` from the command center (do not mint a new identity).
/// Derives ``exitCode`` from phase transitions because ``BrewOperationPhase`` does not itself carry one:
/// `.running → .idle` ⇒ exit 0; `.failed(.brewCommand(exitCode, _))` ⇒ that exit code; other failure cases ⇒ `-1`.
///
/// This type holds only stored data and its mutation; display-flavoured helpers (status-dot state, export
/// formatting) live as extensions in `BrewFeatureConsole`.
@Observable
@MainActor
public final class CommandJob: Identifiable {
    public let id: BrewOperationID
    public let command: String
    public let startedAt: Date

    public private(set) var phase: BrewOperationPhase
    public private(set) var output: [BrewCommandOutputLine] = []
    public private(set) var exitCode: Int32?

    private let maxOutputLines: Int

    public init(
        id: BrewOperationID,
        command: String,
        startedAt: Date,
        phase: BrewOperationPhase,
        maxOutputLines: Int = 50000,
    ) {
        self.id = id
        self.command = command
        self.startedAt = startedAt
        self.phase = phase
        self.maxOutputLines = maxOutputLines
    }

    public var isTerminal: Bool {
        exitCode != nil
    }

    public var succeeded: Bool {
        exitCode == 0
    }

    public func updatePhase(_ newPhase: BrewOperationPhase) {
        let wasRunning = if case .running = phase { true } else { false }
        phase = newPhase
        switch newPhase {
        case .idle:
            if wasRunning {
                exitCode = 0
            }
        case let .failed(reason):
            exitCode = Self.exitCodeFromFailure(reason) ?? -1
        case .running:
            break
        }
    }

    public func appendOutput(_ line: BrewCommandOutputLine) {
        output.append(line)
        if output.count > maxOutputLines {
            output.removeFirst(output.count - maxOutputLines)
        }
    }

    private static func exitCodeFromFailure(_ reason: OperationFailure) -> Int32? {
        if case let .brewCommand(exitCode, _) = reason {
            return exitCode
        }
        return nil
    }
}

public extension CommandJob {
    /// Materialize a fresh job from operation metadata seen on the phase stream.
    /// Synthesizes the user-facing command string from the operation's ``HomebrewPackageID`` (name)
    /// plus the running ``BrewOperationKind`` (which carries the formula/cask distinction).
    static func materialize(
        id: BrewOperationID,
        kind: BrewOperationKind,
        phase: BrewOperationPhase,
        now: Date = Date(),
    ) -> CommandJob {
        let command = userFacingCommand(kind: kind, name: id.packageID.name)
        return CommandJob(
            id: id,
            command: command,
            startedAt: now,
            phase: phase,
        )
    }

    private static func userFacingCommand(kind: BrewOperationKind, name: String) -> String {
        let verb: String
        let isCask: Bool
        switch kind {
        case .installFormula:
            verb = "install"
            isCask = false
        case .installCask:
            verb = "install"
            isCask = true
        case .upgradeFormula:
            verb = "upgrade"
            isCask = false
        case .upgradeCask:
            verb = "upgrade"
            isCask = true
        case .uninstallFormula:
            verb = "uninstall"
            isCask = false
        case .uninstallCask:
            verb = "uninstall"
            isCask = true
        }
        if isCask {
            return "brew \(verb) --cask \(name)"
        }
        return "brew \(verb) \(name)"
    }
}
