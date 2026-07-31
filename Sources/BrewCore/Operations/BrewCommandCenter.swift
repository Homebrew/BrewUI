//
//  BrewCommandCenter.swift
//  BrewCore
//

import Foundation

/// Coordinates mutating `brew` operations and cross-surface visibility (`ARCHITECTURE.md` — command execution).
public protocol BrewCommandCenter: Actor {
    /// Snapshot for UI — ``BrewOperationPhase/idle`` when no state is tracked for `id`.
    func phase(for id: BrewOperationID) async -> BrewOperationPhase

    /// All tracked phases keyed by ``BrewOperationID``. Missing keys are equivalent to ``BrewOperationPhase/idle``.
    func phaseByID() async -> [BrewOperationID: BrewOperationPhase]

    /// `true` while work for `id` is actively running (not failed-only).
    func isActive(id: BrewOperationID) async -> Bool

    /// Push-based phase updates for `id` — yields the current phase once when subscribed, then each subsequent phase transition.
    /// Cancel the consuming task (e.g. end of a SwiftUI ``View/task``) and unregister via ``AsyncStream/Continuation/onTermination``.
    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase>

    /// Push-based phase updates for **any** operation id — yields each phase transition `(id, phase)` with **no** initial replay.
    /// Cancel the consuming task and unregister via ``AsyncStream/Continuation/onTermination``.
    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)>

    /// Push-based subprocess output for `id` — yields buffered lines on subscribe, then each new line as the
    /// underlying `Process` emits it. Cancel the consuming task and unregister via ``AsyncStream/Continuation/onTermination``.
    func outputChanges(for id: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine>

    /// Push-based subprocess output for **any** operation id — yields each line `(id, line)` with **no** initial replay.
    /// Cancel the consuming task and unregister via ``AsyncStream/Continuation/onTermination``.
    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)>

    /// Run `command` keyed by `id` and **capture** its faithful ``CommandOutput`` for inspection/parsing.
    ///
    /// Output is broadcast as it arrives (see ``outputChanges(for:)``) with colour forced on, so the returned
    /// bytes may contain ANSI codes — callers that parse must strip them (see `BrewDoctorRepository`). A
    /// non-zero exit is **not** treated as a failure (e.g. `brew doctor` exits non-zero on warnings); inspect
    /// ``CommandOutput/terminationStatus`` if you care. For reads (`brew doctor`, list, info).
    ///
    /// **Concurrency:** Conforming types such as ``SerialBrewCommandCenter`` run work **serially**.
    /// **Idempotence:** A second call for the same `id` while the first is in flight awaits and returns the same output.
    @discardableResult
    func capture(_ command: BrewCommand, id: BrewOperationID) async throws -> CommandOutput

    /// **Perform** `command` for effect: broadcast its output with colour forced on, discard the result, and
    /// throw ``BrewCommandError/failed(exitCode:stderr:)`` on a non-zero exit. For mutations (install/upgrade/…).
    func perform(_ command: BrewCommand, id: BrewOperationID) async throws
}
