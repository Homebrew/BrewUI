//
//  InstalledDetailsViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledDetailsViewModelTests {
    @Test @MainActor func `displayCommand uses selected row name before load`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.displayCommand == "brew info wget")
    }

    @Test @MainActor func `displayCommand uses loaded details name after load`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget@2")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        #expect(viewModel.displayCommand == "brew info wget@2")
    }

    @Test @MainActor func `homepageURL returns valid http URL from loaded details`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "https://example.com"
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: loadedDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)

        #expect(viewModel.homepageURL?.absoluteString == "https://example.com")
    }

    @Test @MainActor func `homepageURL returns nil for invalid homepage`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "not-a-url"
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: loadedDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `homepageURL returns nil outside loaded state`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `load maps package not found to user-facing error`() async {
        let row = InstalledPackageRow(name: "ghost", kind: .formula, description: "", installedVersion: "v1")
        let repository = StubDetailsRepository(error: PackageDetailsRepositoryError.packageNotFound(name: "ghost"))
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: {
            if case .error = $0 {
                return true
            }
            return false
        })

        let expected = String(
            localized: "Could not load package details from Homebrew.",
            comment: "Installed detail error when package is missing in brew info JSON response",
        )
        #expect(viewModel.state == .error(expected))
    }

    @Test @MainActor func `load maps stderr from brew command failure`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let repository = StubDetailsRepository(error: BrewCommandError.failed(exitCode: 1, stderr: "permission denied"))
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: {
            if case .error = $0 {
                return true
            }
            return false
        })

        #expect(viewModel.state == .error("permission denied"))
    }

    @Test @MainActor func `later load result wins when previous request finishes last`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let repository = DeferredDetailsRepository()
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        viewModel.load()
        await repository.waitForCallCount(1)
        viewModel.load()
        await repository.waitForCallCount(2)

        await repository.resolve(callIndex: 1, with: .success(details(name: "wget-second")))
        await waitForState(on: viewModel, toSatisfy: {
            if case let .loaded(details) = $0 {
                return details.name == "wget-second"
            }
            return false
        })

        await repository.resolve(callIndex: 0, with: .success(details(name: "wget-first")))
        await Task.yield()

        guard case let .loaded(loadedDetails) = viewModel.state else {
            Issue.record("expected loaded state after second request result")
            return
        }
        #expect(loadedDetails.name == "wget-second")
    }

    @Test @MainActor func `upgradeDisplayCommand reflects formula name`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade wget")
    }

    @Test @MainActor func `upgradeDisplayCommand uses cask terminal flags`() {
        let row = InstalledPackageRow(
            name: "docker",
            kind: .cask,
            description: "",
            installedVersion: "v1",
        )
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "docker", kind: .cask)),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade --cask docker")
    }

    @Test @MainActor func `upgradeDisplayCommand prefers loaded details package name`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget@2")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade wget@2")
    }

    @Test @MainActor func `showsUpgradeChrome follows selected row update flag`() {
        let outdated = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        let outdatedVM = InstalledDetailsViewModel(
            selectedRow: outdated,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(outdatedVM.showsUpgradeChrome)

        let current = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let currentVM = InstalledDetailsViewModel(
            selectedRow: current,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(!currentVM.showsUpgradeChrome)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle is nil when package is current`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradePrimaryButtonTitle == nil)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle includes update version label`() {
        let row = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v9.9.9",
        )
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradePrimaryButtonTitle?.contains("v9.9.9") == true)
    }

    @Test @MainActor func `upgrade invokes onUpgradeSuccess`() async {
        let spy = UpgradeCallbackSpy()
        let row = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            onUpgradeSuccess: { await spy.record() },
        )

        await viewModel.upgradeSelectedPackage()
        #expect(await spy.invocationCount == 1)
        #expect(viewModel.upgradeErrorMessage == nil)
    }

    @Test @MainActor func `load syncs upgradeOperationPhase from command center`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let center = ConstantPhaseCommandCenter(phase: .running(.upgradeFormula))
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: center,
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        await waitForUpgradePhase(on: viewModel) { phase in
            if case .running(.upgradeFormula) = phase {
                return true
            }
            return false
        }
    }

    @Test @MainActor func `upgrade failure sets upgrade error message`() async {
        let row = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.failed(exitCode: 1, stderr: "upgrade blocked"),
            ),
        )

        await viewModel.upgradeSelectedPackage()
        #expect(viewModel.upgradeErrorMessage == "upgrade blocked")
    }
}

private actor ConstantPhaseCommandCenter: BrewCommandCenter {
    private let fixedPhase: BrewOperationPhase

    init(phase: BrewOperationPhase) {
        fixedPhase = phase
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        _ = id
        return fixedPhase
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id: BrewOperationID) async -> Bool {
        _ = id
        if case .running = fixedPhase {
            return true
        }
        return false
    }

    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        _ = id
        _ = command
    }
}

private actor ThrowingSubmitCommandCenter: BrewCommandCenter {
    let error: Error

    init(error: BrewCommandError) {
        self.error = error
    }

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

    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        _ = id
        _ = command
        throw error
    }
}

private actor UpgradeCallbackSpy {
    private(set) var invocationCount = 0

    func record() {
        invocationCount += 1
    }
}

private struct StubDetailsRepository: PackageDetailsRepository {
    var error: Error

    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> InstalledPackageDetails {
        throw error
    }
}

private struct SuccessDetailsRepository: PackageDetailsRepository {
    let details: InstalledPackageDetails

    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> InstalledPackageDetails {
        details
    }
}

private actor DeferredDetailsRepository: PackageDetailsRepository {
    private var continuations: [CheckedContinuation<InstalledPackageDetails, Error>] = []
    private var callCount: Int = 0

    func loadPackageDetails(
        named _: String,
        preferredKind _: InstalledPackageKind?,
    ) async throws -> InstalledPackageDetails {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForCallCount(_ expected: Int) async {
        while callCount < expected {
            await Task.yield()
        }
    }

    func resolve(callIndex: Int, with result: Result<InstalledPackageDetails, Error>) {
        guard continuations.indices.contains(callIndex) else {
            return
        }
        let continuation = continuations[callIndex]
        switch result {
        case let .success(details):
            continuation.resume(returning: details)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}

@MainActor
private func waitForState(
    on viewModel: InstalledDetailsViewModel,
    toSatisfy predicate: @escaping (InstalledDetailsLoadState) -> Bool,
) async {
    for _ in 0 ..< 100 {
        if predicate(viewModel.state) {
            return
        }
        await Task.yield()
    }
    Issue.record("timed out waiting for expected details state")
}

@MainActor
private func waitForUpgradePhase(
    on viewModel: InstalledDetailsViewModel,
    toSatisfy predicate: @escaping (BrewOperationPhase) -> Bool,
) async {
    for _ in 0 ..< 100 {
        if predicate(viewModel.upgradeOperationPhase) {
            return
        }
        await Task.yield()
    }
    Issue.record("timed out waiting for expected upgradeOperationPhase")
}

private func details(name: String, kind: InstalledPackageKind = .formula) -> InstalledPackageDetails {
    InstalledPackageDetails(
        name: name,
        kind: kind,
        description: "desc",
        version: "1.0.0",
        installedVersions: ["1.0.0"],
        homepage: nil,
        dependencies: [],
    )
}

private func isLoaded(_ state: InstalledDetailsLoadState) -> Bool {
    if case .loaded = state {
        return true
    }
    return false
}
