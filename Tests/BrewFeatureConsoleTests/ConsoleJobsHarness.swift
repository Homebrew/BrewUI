//
//  ConsoleJobsHarness.swift
//  BrewFeatureConsoleTests
//

import BrewCore
@testable import BrewFeatureConsole
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation

/// Wires a ``ControllableJobsCommandCenter`` to a real ``BrewCommandJobsRepository`` (and a
/// ``ConsoleViewModel`` projecting it), then drives the repository by emitting through the center's
/// streams. Each `emit` settles the cooperative pipeline so the repository has processed the event
/// before the test asserts.
@MainActor
final class ConsoleJobsHarness {
    let center = ControllableJobsCommandCenter()
    let repository: BrewCommandJobsRepository
    let viewModel: ConsoleViewModel

    init() {
        repository = BrewCommandJobsRepository(commandCenter: center)
        viewModel = ConsoleViewModel(repository: repository)
    }

    /// Await the repository's init-time stream subscriptions before emitting, so buffered events reach it.
    func awaitReady() async {
        for _ in 0 ..< 200 {
            if await center.hasPhaseSubscriber(), await center.hasOutputSubscriber() {
                return
            }
            await Task.yield()
        }
    }

    func emit(id: BrewOperationID, phase: BrewOperationPhase) async {
        await center.emitPhase(id: id, phase: phase)
        await settle()
    }

    func emit(id: BrewOperationID, output line: BrewCommandOutputLine) async {
        await center.emitOutput(id: id, line: line)
        await settle()
    }

    /// The most recent console job routed from a given operation id. Tests drive the repository by
    /// ``BrewOperationID`` (the command center's key) but the cache is now keyed by per-run
    /// ``CommandJobID``, so this bridges the two for assertions.
    func job(for operationID: BrewOperationID) -> CommandJob? {
        repository.orderedIDs
            .compactMap { repository.jobs[$0] }
            .last { $0.operationID == operationID }
    }

    /// Operation ids of the ordered jobs, in tab order — the operation-keyed view of ``orderedIDs``.
    var orderedOperationIDs: [BrewOperationID] {
        repository.orderedIDs.compactMap { repository.jobs[$0]?.operationID }
    }

    private func settle() async {
        for _ in 0 ..< 50 {
            await Task.yield()
        }
    }
}
