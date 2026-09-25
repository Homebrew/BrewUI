import BrewCLI
import BrewCore
import Foundation

/// Plays back a fixed phase timeline via `phaseChanges(for:)`, then finishes — drives
/// Discover install-busy consumers (`observeRowUpdates` / `observeInstallUpdates`) to a
/// deterministic terminal state.
actor InstallPhaseSequenceCommandCenter: BrewCommandCenter {
    private let phases: [BrewOperationPhase]

    init(phases: [BrewOperationPhase]) {
        self.phases = phases
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        phases.last ?? .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    @discardableResult
    func capture(_ command: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        _ = id
        _ = command
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            for phase in phases {
                continuation.yield(phase)
            }
            continuation.finish()
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}
