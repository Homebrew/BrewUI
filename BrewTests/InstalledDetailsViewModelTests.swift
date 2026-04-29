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
        let viewModel = InstalledDetailsViewModel(selectedRow: row, repository: SuccessDetailsRepository(details: details(name: "wget")))
        #expect(viewModel.displayCommand == "brew info wget")
    }

    @Test @MainActor func `displayCommand uses loaded details name after load`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selectedRow: row,
            repository: SuccessDetailsRepository(details: details(name: "wget@2")),
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
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `homepageURL returns nil outside loaded state`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(selectedRow: row, repository: SuccessDetailsRepository(details: details(name: "wget")))

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `load maps package not found to user-facing error`() async {
        let row = InstalledPackageRow(name: "ghost", kind: .formula, description: "", installedVersion: "v1")
        let repository = StubDetailsRepository(error: PackageDetailsRepositoryError.packageNotFound(name: "ghost"))
        let viewModel = InstalledDetailsViewModel(selectedRow: row, repository: repository)
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
        let viewModel = InstalledDetailsViewModel(selectedRow: row, repository: repository)
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
        let viewModel = InstalledDetailsViewModel(selectedRow: row, repository: repository)

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
}

private struct StubDetailsRepository: PackageDetailsRepository {
    var error: Error

    func loadPackageDetails(named _: String, preferredKind _: InstalledPackageKind?) async throws -> InstalledPackageDetails {
        throw error
    }
}

private struct SuccessDetailsRepository: PackageDetailsRepository {
    let details: InstalledPackageDetails

    func loadPackageDetails(named _: String, preferredKind _: InstalledPackageKind?) async throws -> InstalledPackageDetails {
        details
    }
}

private actor DeferredDetailsRepository: PackageDetailsRepository {
    private var continuations: [CheckedContinuation<InstalledPackageDetails, Error>] = []
    private var callCount: Int = 0

    func loadPackageDetails(named _: String, preferredKind _: InstalledPackageKind?) async throws -> InstalledPackageDetails {
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

private func details(name: String) -> InstalledPackageDetails {
    InstalledPackageDetails(
        name: name,
        kind: .formula,
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
