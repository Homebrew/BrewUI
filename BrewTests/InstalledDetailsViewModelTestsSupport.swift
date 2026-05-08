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

actor UpgradeCallbackSpy {
    private(set) var invocationCount = 0
    func record() {
        invocationCount += 1
    }
}

@MainActor
func waitForUpgradeCallback(spy: UpgradeCallbackSpy, expectedCount: Int) async {
    for _ in 0 ..< 100 {
        if await spy.invocationCount == expectedCount { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for upgrade callback")
}

struct StubDetailsRepository: PackageDetailsRepository {
    var error: Error
    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> BrewPackage {
        throw error
    }
}

struct SuccessDetailsRepository: PackageDetailsRepository {
    let details: BrewPackage
    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> BrewPackage {
        details
    }
}

actor DeferredDetailsRepository: PackageDetailsRepository {
    private var continuations: [CheckedContinuation<BrewPackage, Error>] = []
    private var callCount: Int = 0
    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> BrewPackage {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in continuations.append(continuation) }
    }

    func waitForCallCount(_ expected: Int) async {
        while callCount < expected {
            await Task.yield()
        }
    }

    func resolve(callIndex: Int, with result: Result<BrewPackage, Error>) {
        guard continuations.indices.contains(callIndex) else { return }
        switch result {
        case let .success(details): continuations[callIndex].resume(returning: details)
        case let .failure(error): continuations[callIndex].resume(throwing: error)
        }
    }
}

actor SequencedDetailsRepository: PackageDetailsRepository {
    private let results: [Result<BrewPackage, Error>]
    private(set) var callCount: Int = 0
    init(results: [Result<BrewPackage, Error>]) {
        self.results = results
    }

    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> BrewPackage {
        let index = callCount
        callCount += 1
        guard results.indices.contains(index) else {
            Issue.record("missing stubbed details result for call \(index)")
            throw PackageDetailsRepositoryError.packageNotFound(name: "missing")
        }
        return try results[index].get()
    }

    func waitForCallCount(_ expected: Int) async {
        while callCount < expected {
            await Task.yield()
        }
    }
}

@MainActor
func waitForState(
    on viewModel: InstalledDetailsViewModel,
    toSatisfy predicate: @escaping (InstalledDetailsLoadState) -> Bool,
) async {
    for _ in 0 ..< 100 {
        if predicate(viewModel.state) { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for expected details state")
}

@MainActor
func waitForUpgradePhase(
    on viewModel: InstalledDetailsViewModel,
    toSatisfy predicate: @escaping (BrewOperationPhase) -> Bool,
) async {
    for _ in 0 ..< 100 {
        if predicate(viewModel.upgradeOperationPhase) { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for expected upgradeOperationPhase")
}

@MainActor
func waitForUpgradeError(on viewModel: InstalledDetailsViewModel) async {
    for _ in 0 ..< 100 {
        if viewModel.upgradeErrorMessage != nil { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for upgradeErrorMessage")
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

func isLoaded(_ state: InstalledDetailsLoadState) -> Bool {
    if case .loaded = state { return true }
    return false
}
