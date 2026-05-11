@testable import Brew
import Foundation
import Testing

actor ConstantPhaseCommandCenter: BrewCommandCenter {
    private let fixedPhase: BrewOperationPhase

    init(phase: BrewOperationPhase) {
        fixedPhase = phase
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        fixedPhase
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        if case .running = fixedPhase { return true }
        return false
    }

    func submit(id _: BrewOperationID, command _: any BrewMutatingCommand) async throws {}
    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(fixedPhase)
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}

actor ThrowingSubmitCommandCenter: BrewCommandCenter {
    let error: Error
    init(error: BrewCommandError) {
        self.error = error
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        false
    }

    func submit(id _: BrewOperationID, command _: any BrewMutatingCommand) async throws {
        throw error
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(.idle)
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}

actor DeferredSubmitCommandCenter: BrewCommandCenter {
    private(set) var submitCallCount: Int = 0
    private var continuation: CheckedContinuation<Void, Never>?
    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        submitCallCount > 0
    }

    func submit(id _: BrewOperationID, command _: any BrewMutatingCommand) async throws {
        submitCallCount += 1
        await withCheckedContinuation { continuation in self.continuation = continuation }
    }

    func resolveSubmit() {
        continuation?.resume(); continuation = nil
    }

    func waitForSubmitCallCount(_ expected: Int) async {
        while submitCallCount < expected {
            await Task.yield()
        }
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(.idle)
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}

/// Waits until upgrade busy chrome clears (``InstalledDetailsViewModel/isUpgrading``), after a short yield budget so async submit work can run.
@MainActor
func waitForUpgradeAttemptToFinish(on viewModel: InstalledDetailsViewModel) async {
    for step in 0 ..< 300 {
        await Task.yield()
        if step >= 10, !viewModel.isUpgrading {
            return
        }
    }
    Issue.record("timed out waiting for isUpgrading to clear")
}

@MainActor
func waitForUpgradeError(on viewModel: InstalledDetailsViewModel) async {
    for _ in 0 ..< 100 {
        if viewModel.upgradeErrorMessage != nil { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for upgradeErrorMessage")
}

/// Runs ``InstalledDetailsViewModel/observeRowUpdates()`` concurrently — required for upgrades to mirror the detail column lifecycle.
@MainActor
func withInstalledDetailPhaseObservation(
    on viewModel: InstalledDetailsViewModel,
    _ body: () async -> Void,
) async {
    let observer = Task { await viewModel.observeRowUpdates() }
    defer { observer.cancel() }
    await Task.yield()
    await body()
}

func details(
    name: String,
    kind: InstalledPackageKind = .formula,
    version: String = "1.0.0",
) -> BrewPackage {
    BrewPackage(
        name: name,
        kind: kind,
        description: "desc",
        homepage: "",
        latestVersion: version,
        installedVersions: [version],
        dependencies: [],
        outdated: false,
    )
}
