//
//  CommandJob.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Per-run identity for a console job (tab).
///
/// Deliberately distinct from ``BrewOperationID``, which the command center *reuses* as a routing/dedup
/// key across successive operations on the same package (install, then upgrade, then uninstall of `gh` all
/// share one ``BrewOperationID``). Each materialized ``CommandJob`` mints a fresh ``CommandJobID`` so those
/// successive runs surface as separate tabs rather than collapsing onto the first one.
public struct CommandJobID: Hashable, Sendable {
    private let rawValue: UUID

    public init() {
        rawValue = UUID()
    }
}

/// One brew command's lifecycle as observed by the console UI: identity, phase, streamed output, and final exit code.
///
/// Carries its own per-run ``CommandJobID`` (the tab identity) plus the ``BrewOperationID`` it was routed by
/// (the command center's key — see ``CommandJobID`` for why they differ).
/// Derives ``exitCode`` from phase transitions because ``BrewOperationPhase`` does not itself carry one:
/// `.running → .idle` ⇒ exit 0; `.failed(.brewCommand(exitCode, _))` ⇒ that exit code; other failure cases ⇒ `-1`.
///
/// This type holds only stored data and its mutation; display-flavoured helpers (status-dot state, export
/// formatting) live as extensions in `BrewFeatureConsole`.
@Observable
@MainActor
public final class CommandJob: Identifiable {
    public let id: CommandJobID
    public let operationID: BrewOperationID
    public let command: String
    public let startedAt: Date

    public private(set) var phase: BrewOperationPhase
    public private(set) var output: [BrewCommandOutputLine] = []
    public private(set) var exitCode: Int32?

    private let maxOutputLines: Int

    public init(
        operationID: BrewOperationID,
        command: String,
        startedAt: Date,
        phase: BrewOperationPhase,
        maxOutputLines: Int = 50000,
    ) {
        id = CommandJobID()
        self.operationID = operationID
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

@MainActor
public extension CommandJob {
    /// Materialize a fresh job from operation metadata seen on the phase stream.
    /// For package ids, synthesizes the user-facing command string from the ``HomebrewPackageID`` (name)
    /// plus the running ``BrewOperationKind`` (which carries the formula/cask distinction). For maintenance
    /// ids the command isn't reconstructable from a package, so the id's stored `displayCommand` is used verbatim.
    static func materialize(
        id: BrewOperationID,
        kind: BrewOperationKind,
        phase: BrewOperationPhase,
        now: Date = Date(),
    ) -> CommandJob {
        let command: String = switch id {
        case let .package(packageID):
            userFacingCommand(kind: kind, name: packageID.name)
        case let .maintenance(_, displayCommand):
            displayCommand
        case let .bulkUpgrade(selection):
            selection.displayCommand
        }
        return CommandJob(
            operationID: id,
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
        case .doctorFix, .doctorRead, .upgradeAll:
            // Unreachable: doctor kinds use `.maintenance` ids, and `.upgradeAll` uses `.bulkUpgrade` —
            // both materialize their display command in the outer switch rather than via package-name
            // synthesis. Fall back defensively.
            return "brew"
        }
        if isCask {
            return "brew \(verb) --cask \(name)"
        }
        return "brew \(verb) \(name)"
    }
}
