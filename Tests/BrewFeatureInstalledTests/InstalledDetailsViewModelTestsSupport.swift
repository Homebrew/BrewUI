import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
@testable import BrewRepositoryInterfaces
import Foundation
import Testing

actor ConstantPhaseCommandCenter: BrewCommandCenter {
    private let fixedPhase: BrewOperationPhase
    private let operationID: BrewOperationID

    init(phase: BrewOperationPhase, id: BrewOperationID = .package(.formula(name: "wget"))) {
        fixedPhase = phase
        operationID = id
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        id == operationID ? fixedPhase : .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        fixedPhase.isRunning ? [operationID: fixedPhase] : [:]
    }

    @discardableResult
    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_: BrewCommand, id _: BrewOperationID) async throws {}

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(fixedPhase)
            continuation.finish()
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}

actor ThrowingSubmitCommandCenter: BrewCommandCenter {
    let error: Error
    init(error: Error) {
        self.error = error
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    @discardableResult
    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        throw error
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
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

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}

/// On each submit, latches the operation into a running phase retained for `runningPhases()` and broadcast
/// on `allPhaseChanges()`, so a tracker sees it in-flight whether it subscribes before or after. Never idles.
actor RunningSubmitCountingCommandCenter: BrewCommandCenter {
    private struct Listener {
        let token: UUID
        let continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation
    }

    private(set) var submitCallCount: Int = 0
    private let runningPhase: BrewOperationPhase
    private var trackedPhasesByID: [BrewOperationID: BrewOperationPhase] = [:]
    private var listeners: [Listener] = []

    init(phase: BrewOperationPhase = .running(.upgradeFormula)) {
        runningPhase = phase
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        trackedPhasesByID[id] ?? .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        trackedPhasesByID
    }

    @discardableResult
    func capture(_: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        submitCallCount += 1
        trackedPhasesByID[id] = runningPhase
        for listener in listeners {
            listener.continuation.yield((id, runningPhase))
        }
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
            let token = UUID()
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeListener(token: token) }
            }
            registerListener(token: token, continuation: continuation)
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }

    private func registerListener(
        token: UUID,
        continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation,
    ) {
        listeners.append(Listener(token: token, continuation: continuation))
    }

    private func removeListener(token: UUID) {
        listeners.removeAll { $0.token == token }
    }
}

actor SubmitRecordingCommandCenter: BrewCommandCenter {
    private(set) var recordedSubmitEntries: [(id: BrewOperationID, kind: BrewOperationKind)] = []

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    @discardableResult
    func capture(_ command: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        recordedSubmitEntries.append((id, command.operationKind))
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func waitForSubmitCallCount(_ expected: Int) async {
        for _ in 0 ..< 1000 {
            if recordedSubmitEntries.count >= expected { return }
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

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
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

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    @discardableResult
    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        submitCallCount += 1
        await withCheckedContinuation { continuation in self.continuation = continuation }
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
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

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}

/// Waits until upgrade busy chrome clears (``InstalledPackageDetailViewModel/isUpgrading``), after a short yield budget so async submit work can run.
@MainActor
func waitForUpgradeAttemptToFinish(on viewModel: InstalledPackageDetailViewModel) async {
    for step in 0 ..< 300 {
        await Task.yield()
        if step >= 10, !viewModel.isUpgrading {
            return
        }
    }
    Issue.record("timed out waiting for isUpgrading to clear")
}

@MainActor
func waitForUpgradeError(on viewModel: InstalledPackageDetailViewModel) async {
    for _ in 0 ..< 100 {
        if viewModel.upgradeErrorMessage != nil { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for upgradeErrorMessage")
}

@MainActor
func waitForUpgrading(on viewModel: InstalledPackageDetailViewModel) async {
    for _ in 0 ..< 100 {
        if viewModel.isUpgrading { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for isUpgrading")
}

@MainActor
func waitForUninstallAttemptToFinish(on viewModel: InstalledPackageDetailViewModel) async {
    for step in 0 ..< 300 {
        await Task.yield()
        if step >= 10, !viewModel.isUninstalling {
            return
        }
    }
    Issue.record("timed out waiting for isUninstalling to clear")
}

@MainActor
func waitForUninstallError(on viewModel: InstalledPackageDetailViewModel) async {
    for _ in 0 ..< 100 {
        if viewModel.uninstallErrorMessage != nil { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for uninstallErrorMessage")
}

@MainActor
func waitForUninstalling(on viewModel: InstalledPackageDetailViewModel) async {
    for _ in 0 ..< 100 {
        if viewModel.isUninstalling { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for isUninstalling")
}

/// Runs ``InstalledPackageDetailViewModel/observeRowUpdates()`` concurrently — required for upgrades to mirror the detail column lifecycle.
@MainActor
func withInstalledDetailPhaseObservation(
    on viewModel: InstalledPackageDetailViewModel,
    _ body: () async -> Void,
) async {
    let observer = Task { await viewModel.observeRowUpdates() }
    defer { observer.cancel() }
    await Task.yield()
    await body()
}

@MainActor
func makeInstalledDetailsViewModel(
    package: InstalledBrewPackage,
    brewCommandCenter: any BrewCommandCenter = NoopBrewCommandCenter.forTesting(),
    installedDependentsRepository: (any InstalledDependentsRepository)? = nil,
    installedInventoryReading: (any InstalledInventoryReading)? = nil,
) -> InstalledPackageDetailViewModel {
    InstalledPackageDetailViewModel(
        package: package,
        brewCommandCenter: brewCommandCenter,
        commandFactory: StubMutatingCommandFactory(),
        installedDependentsRepository: installedDependentsRepository ?? EmptyInstalledDependentsRepository(),
        installedInventoryReading: installedInventoryReading ?? EmptyInstalledInventoryReading(),
    )
}

func details(
    name: String,
    kind: InstalledPackageKind = .formula,
    version: String = "1.0.0",
) -> InstalledBrewPackage {
    InstalledBrewPackage(
        package: BrewPackage(
            name: name,
            displayName: name,
            kind: kind,
            description: "desc",
            homepage: "",
            latestVersion: version,
            dependencies: [],
        ),
        installedVersions: [version],
        outdated: false,
    )
}
