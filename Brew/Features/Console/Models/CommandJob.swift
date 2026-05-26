//
//  CommandJob.swift
//  Brew
//

import Foundation

/// One brew command's lifecycle as observed by the console UI: identity, phase, streamed output, and final exit code.
///
/// Reuses ``BrewOperationID`` from the command center (do not mint a new identity).
/// Derives ``exitCode`` from phase transitions because ``BrewOperationPhase`` does not itself carry one:
/// `.running → .idle` ⇒ exit 0; `.failed(.brewCommand(exitCode, _))` ⇒ that exit code; other failure cases ⇒ `-1`.
@Observable
@MainActor
final class CommandJob: Identifiable {
    let id: BrewOperationID
    let command: String
    let scope: JobScope
    let startedAt: Date

    private(set) var phase: BrewOperationPhase
    private(set) var output: [BrewCommandOutputLine] = []
    private(set) var exitCode: Int32?

    private static let maxOutputLines = 50000

    init(
        id: BrewOperationID,
        command: String,
        scope: JobScope,
        startedAt: Date,
        phase: BrewOperationPhase,
    ) {
        self.id = id
        self.command = command
        self.scope = scope
        self.startedAt = startedAt
        self.phase = phase
    }

    var isTerminal: Bool {
        exitCode != nil
    }

    var succeeded: Bool {
        exitCode == 0
    }

    func updatePhase(_ newPhase: BrewOperationPhase) {
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

    func appendOutput(_ line: BrewCommandOutputLine) {
        output.append(line)
        if output.count > Self.maxOutputLines {
            output.removeFirst(output.count - Self.maxOutputLines)
        }
    }

    private static func exitCodeFromFailure(_ reason: OperationFailure) -> Int32? {
        if case let .brewCommand(exitCode, _) = reason {
            return exitCode
        }
        return nil
    }
}

extension CommandJob {
    /// Materialize a fresh job from operation metadata seen on the phase stream.
    /// Synthesizes the user-facing command string from the Homebrew ``BrewOperationID`` raw value
    /// (`"formula:gh"` / `"cask:firefox"`) plus the running ``BrewOperationKind``.
    static func materialize(
        id: BrewOperationID,
        kind: BrewOperationKind,
        phase: BrewOperationPhase,
        now: Date = Date(),
    ) -> CommandJob {
        let parsed = parseHomebrewID(id)
        let name = parsed?.name ?? id.rawValue
        let command = userFacingCommand(kind: kind, name: name)
        let scope: JobScope = parsed.map { .package(name: $0.name) } ?? .global
        return CommandJob(
            id: id,
            command: command,
            scope: scope,
            startedAt: now,
            phase: phase,
        )
    }

    private static func parseHomebrewID(_ id: BrewOperationID) -> (kind: String, name: String)? {
        let parts = id.rawValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard
            parts.count == 2,
            !parts[0].isEmpty,
            !parts[1].isEmpty
        else {
            return nil
        }
        return (kind: String(parts[0]), name: String(parts[1]))
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
