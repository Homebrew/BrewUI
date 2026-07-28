//
//  BrewCommandCenter.swift
//  BrewCore
//

import Foundation

/// Coordinates mutating `brew` operations and cross-surface visibility (`ARCHITECTURE.md` — command execution).
public protocol BrewCommandCenter: Actor {
    /// Snapshot for UI — ``BrewOperationPhase/idle`` when no state is tracked for `id`.
    func phase(for id: BrewOperationID) async -> BrewOperationPhase

    /// Push-based phase updates for `id` — yields the current phase once when subscribed, then each subsequent phase transition.
    /// Cancel the consuming task (e.g. end of a SwiftUI ``View/task``) and unregister via ``AsyncStream/Continuation/onTermination``.
    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase>

    /// Push-based phase updates for **any** operation id — yields each phase transition `(id, phase)` with **no** initial replay.
    /// Cancel the consuming task and unregister via ``AsyncStream/Continuation/onTermination``.
    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)>

    /// Push-based subprocess output for **any** operation id — yields each line `(id, line)` with **no** initial replay.
    /// Cancel the consuming task and unregister via ``AsyncStream/Continuation/onTermination``.
    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)>

    /// Enqueue mutating work keyed by `id`.
    ///
    /// **Concurrency:** Conforming types such as ``SerialBrewCommandCenter`` run work **serially** (one mutating operation at a time).
    /// **Idempotence:** A second `submit` for the same `id` while the first is in flight awaits the same result;
    /// the command runs once.
    /// **Phase:** Running visibility uses ``BrewMutatingCommand/operationKind`` from `command` (no separate kind argument).
    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws
}
