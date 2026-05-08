//
//  InstalledViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledViewModelTests {
    @Test @MainActor func `load produces expected package sections`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.count == 1)
        #expect(content.caskPackages.count == 1)
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `toggleSelection updates selected package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.toggleSelection(for: selectedID)
        #expect(vm.selectedPackage?.id == selectedID)
    }

    @Test @MainActor func `clearSelection clears selected package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.toggleSelection(for: selectedID)
        vm.clearSelection()
        #expect(vm.selectedPackage == nil)
    }

    @Test @MainActor func `command center running to idle triggers installed refresh`() async {
        let commandCenter = ControllableAllPhasesCommandCenter()
        let repo = CountingInstalledRepository()
        let vm = InstalledViewModel(
            repository: repo,
            brewCommandCenter: commandCenter,
        )
        await vm.load()
        #expect(await repo.loadCallCount == 1)
        await waitForPhaseSubscriber(commandCenter: commandCenter)

        let opID = BrewOperationID(kind: .formula, name: "git")
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeFormula))
        await commandCenter.emitPhase(id: opID, phase: .idle)
        await expectLoadCount(atLeast: 2, repo: repo)
        #expect(await repo.loadCallCount == 2)
    }

    @Test @MainActor func `command center running to failed does not trigger installed refresh`() async {
        let commandCenter = ControllableAllPhasesCommandCenter()
        let repo = CountingInstalledRepository()
        let vm = InstalledViewModel(
            repository: repo,
            brewCommandCenter: commandCenter,
        )
        await vm.load()
        #expect(await repo.loadCallCount == 1)
        await waitForPhaseSubscriber(commandCenter: commandCenter)

        let opID = BrewOperationID(kind: .formula, name: "git")
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeFormula))
        await commandCenter.emitPhase(id: opID, phase: .failed(reason: .brewExecutableNotFound))
        await settleAsync()
        #expect(await repo.loadCallCount == 1)
    }

    @Test @MainActor func `multiple running to idle completions trigger multiple refreshes`() async {
        let commandCenter = ControllableAllPhasesCommandCenter()
        let repo = CountingInstalledRepository()
        let vm = InstalledViewModel(
            repository: repo,
            brewCommandCenter: commandCenter,
        )
        await vm.load()
        await waitForPhaseSubscriber(commandCenter: commandCenter)
        let opID = BrewOperationID(kind: .formula, name: "git")
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeFormula))
        await commandCenter.emitPhase(id: opID, phase: .idle)
        await expectLoadCount(atLeast: 2, repo: repo)
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeCask))
        await commandCenter.emitPhase(id: opID, phase: .idle)
        await expectLoadCount(atLeast: 3, repo: repo)
        #expect(await repo.loadCallCount == 3)
    }
}

@MainActor
private func waitForPhaseSubscriber(commandCenter: ControllableAllPhasesCommandCenter) async {
    for _ in 0 ..< 200 {
        if await commandCenter.hasPhaseSubscriber() {
            return
        }
        await Task.yield()
    }
}

@MainActor
private func settleAsync() async {
    for _ in 0 ..< 20 {
        await Task.yield()
    }
}

@MainActor
private func expectLoadCount(atLeast target: Int, repo: CountingInstalledRepository) async {
    for _ in 0 ..< 200 {
        if await repo.loadCallCount >= target {
            return
        }
        await Task.yield()
    }
}

private actor CountingInstalledRepository: InstalledPackagesRepository {
    private(set) var loadCallCount = 0
    private let packages: [BrewPackage]

    init(packages: [BrewPackage] = [.fixture(name: "git", kind: .formula)]) {
        self.packages = packages
    }

    func loadInstalledPackages() async throws -> [BrewPackage] {
        loadCallCount += 1
        return packages
    }
}

private actor ControllableAllPhasesCommandCenter: BrewCommandCenter {
    private typealias AllPhaseTermination =
        AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation.Termination

    private struct AllPhaseStreamListener {
        let token: UUID
        let continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation
    }

    private var allPhaseListeners: [AllPhaseStreamListener] = []

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        _ = id
        return .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id: BrewOperationID) async -> Bool {
        _ = id
        return false
    }

    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        _ = id
        return AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: AllPhaseTermination) in
                Task {
                    await self.removeAllPhaseListener(token: token)
                }
            }
            registerAllPhaseListener(token: token, continuation: continuation)
        }
    }

    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        _ = id
        try await command.run(in: .noopForTestingAndPreviews())
    }

    func emitPhase(id: BrewOperationID, phase: BrewOperationPhase) {
        for listener in allPhaseListeners {
            listener.continuation.yield((id, phase))
        }
    }

    func hasPhaseSubscriber() async -> Bool {
        !allPhaseListeners.isEmpty
    }

    private func registerAllPhaseListener(
        token: UUID,
        continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation,
    ) {
        let listener = AllPhaseStreamListener(token: token, continuation: continuation)
        allPhaseListeners.append(listener)
    }

    private func removeAllPhaseListener(token: UUID) {
        allPhaseListeners.removeAll { $0.token == token }
    }
}
