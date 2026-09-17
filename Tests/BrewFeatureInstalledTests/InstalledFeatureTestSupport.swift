import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation

enum InstalledFeatureTestSupport {
    @MainActor
    static func loadedViewModel(
        formulae: [InstalledBrewPackage] = [],
        casks: [InstalledBrewPackage] = [],
    ) async -> InstalledViewModel {
        let cache = InstalledInventoryCache()
        let snapshot = InstalledInventorySnapshot(fetchedAt: .now, packages: formulae + casks)
        await cache.replace(snapshot)
        let repository = InstalledPackagesTestSupport.repository(
            commandRunner: MockBrewCommandRunner(responses: [:]),
            cache: cache,
        )
        let viewModel = InstalledViewModel(repository: repository)
        await viewModel.load()
        return viewModel
    }
}

/// Plays back a fixed phase timeline for one operation id, then finishes — drives
/// `observeRowUpdates()`-style consumers to a deterministic terminal state.
actor PhaseSequenceCommandCenter: BrewCommandCenter {
    private let phases: [BrewOperationPhase]
    private let operationID: BrewOperationID

    init(phases: [BrewOperationPhase], id: BrewOperationID = .package(.formula(name: "git"))) {
        self.phases = phases
        operationID = id
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        id == operationID ? (phases.last ?? .idle) : .idle
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
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            for phase in phases {
                continuation.yield((operationID, phase))
            }
            continuation.finish()
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}
