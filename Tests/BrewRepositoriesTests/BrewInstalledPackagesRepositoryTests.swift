//
//  BrewInstalledPackagesRepositoryTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewNetworking
@testable import BrewRepositories
import BrewRepositoriesTestSupport
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewInstalledPackagesRepositoryTests {
    @Test @MainActor func `load returns sorted packages for mixed formula and cask json payload`() async throws {
        let json = """
        {
          "formulae": [
            {
              "name": "wget",
              "full_name": "homebrew/core/wget",
              "versions": { "stable": "1.0.0" },
              "installed": [{ "version": "1.24.5" }]
            },
            { "name": "aria2", "versions": { "stable": "2.0.0" }, "installed": [] }
          ],
          "casks": [
            { "token": "zed", "name": ["Zed"], "version": "1.2.3", "installed": "1.2.4" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)

        #expect(packages.map(\.name) == ["aria2", "wget", "zed"])

        let aria2 = try #require(package(named: "aria2", in: packages))
        #expect(aria2.kind == .formula)
        #expect(aria2.displayName == "aria2")
        #expect(aria2.latestVersion == "2.0.0")
        #expect(aria2.installedVersions.isEmpty)

        let wget = try #require(package(named: "wget", in: packages))
        #expect(wget.displayName == "homebrew/core/wget")

        let zed = try #require(package(named: "zed", in: packages))
        #expect(zed.kind == .cask)
        #expect(zed.displayName == "Zed")
        #expect(zed.latestVersion == "1.2.3")
        #expect(zed.installedVersions == ["1.2.4"])
    }

    @Test @MainActor func `load handles mixed payload version fallback rules`() async throws {
        let json = """
        {
          "formulae": [
            {
              "name": "alpha",
              "versions": { "stable": "9.9.9" },
              "installed": [{ "version": "   " }, { "version": "1.2.3" }]
            },
            {
              "name": "beta",
              "versions": { "stable": "2.0.0" },
              "installed": [{ "version": "" }]
            },
            {
              "name": "gamma",
              "installed": [{ "version": "3.1.0" }]
            }
          ],
          "casks": [
            { "token": "echo", "version": "4.0.0", "installed": ["", "4.0.1"] },
            { "token": "delta", "version": "5.0.0", "installed": "" },
            { "token": "charlie", "installed": "6.0.0" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)

        #expect(packages.map(\.name) == ["alpha", "beta", "charlie", "delta", "echo", "gamma"])

        let alpha = try #require(package(named: "alpha", in: packages))
        #expect(alpha.latestVersion == "9.9.9")
        #expect(alpha.installedVersions == ["1.2.3"])

        let beta = try #require(package(named: "beta", in: packages))
        #expect(beta.latestVersion == "2.0.0")
        #expect(beta.installedVersions.isEmpty)

        let gamma = try #require(package(named: "gamma", in: packages))
        #expect(gamma.latestVersion.isEmpty)
        #expect(gamma.installedVersions == ["3.1.0"])

        let echo = try #require(package(named: "echo", in: packages))
        #expect(echo.latestVersion == "4.0.0")
        #expect(echo.installedVersions == ["4.0.1"])

        let delta = try #require(package(named: "delta", in: packages))
        #expect(delta.latestVersion == "5.0.0")
        #expect(delta.installedVersions.isEmpty)

        let charlie = try #require(package(named: "charlie", in: packages))
        #expect(charlie.latestVersion.isEmpty)
        #expect(charlie.installedVersions == ["6.0.0"])
    }

    @Test @MainActor func `load trims strings and deduplicates mapped dependencies`() async throws {
        let json = """
        {
          "formulae": [
            {
              "name": "deps-formula",
              "desc": "  formula desc  ",
              "homepage": " https://example.com ",
              "dependencies": ["openssl", "openssl"],
              "build_dependencies": ["make", "openssl"],
              "recommended_dependencies": ["curl"],
              "optional_dependencies": ["sqlite"],
              "versions": { "stable": "1.0.0" },
              "installed": [{ "version": "1.0.0" }]
            }
          ],
          "casks": [
            {
              "token": "deps-cask",
              "desc": "  cask desc  ",
              "homepage": " https://example.org ",
              "version": "2.0.0",
              "installed": ["2.0.0"],
              "dependencies": {
                "formula": ["git"],
                "cask": ["docker", "git"]
              }
            }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)

        let formula = try #require(package(named: "deps-formula", in: packages))
        #expect(formula.description == "formula desc")
        #expect(formula.homepage == "https://example.com")
        #expect(formula.dependencies == [.formula(name: "openssl")])

        let cask = try #require(package(named: "deps-cask", in: packages))
        #expect(cask.description == "cask desc")
        #expect(cask.homepage == "https://example.org")
        #expect(Set(cask.dependencies) == Set([.formula(name: "git"), .cask(token: "docker"), .cask(token: "git")]))
        #expect(cask.dependencies.count == 3)
    }

    @Test @MainActor func `load maps cask depends_on formula and cask keys and ignores macos`() async throws {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "token": "beid-viewer",
              "installed": ["1.0.0"],
              "depends_on": {
                "macos": {},
                "cask": ["beid-token"]
              }
            },
            {
              "token": "beutl",
              "installed": ["2.0.0"],
              "depends_on": {
                "macos": { ">=": ["12"] },
                "formula": ["ffmpeg@6"]
              }
            }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)

        let beidViewer = try #require(package(named: "beid-viewer", in: packages))
        #expect(beidViewer.dependencies == [.cask(token: "beid-token")])

        let beutl = try #require(package(named: "beutl", in: packages))
        #expect(beutl.dependencies == [.formula(name: "ffmpeg@6")])
    }

    @Test @MainActor func `load tolerates optional and missing fields in json payload`() async {
        let json = """
        {
          "formulae": [
            { "name": "a", "installed": [{ "version": "" }] },
            { "name": "b" }
          ],
          "casks": [
            { "token": "cask-one", "installed": [""] },
            { "token": "cask-two" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)
        #expect(packages.count == 4)
    }

    @Test @MainActor func `load tolerates invalid field types by treating sections as empty`() async {
        let json = """
        {
          "formulae": "not-an-array",
          "casks": { "token": "not-an-array" }
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)
        #expect(packages == [])
    }

    @Test @MainActor func `load fails when installed info exits non zero`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesInstalledInfoFailure(
                standardError: "boom",
                terminationStatus: 1,
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        await repo.load(forceRefresh: true)
        guard case let .failed(error) = repo.state, case let BrewCommandError.failed(_, stderr) = error else {
            Issue.record("expected failed state carrying a brew command error")
            return
        }
        #expect(stderr == "boom")
    }

    @Test @MainActor func `load fails when installed info json is invalid`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: "{ this-is-not-json }",
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        await repo.load(forceRefresh: true)
        guard case .failed = repo.state else {
            Issue.record("expected failed state")
            return
        }
    }

    @Test @MainActor func `load fails with brew lookup error when locator fails`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            locator: MissingBrewExecutableLocator(),
        )
        await repo.load(forceRefresh: true)
        guard case let .failed(error) = repo.state, case BrewLookupError.executableNotFound = error else {
            Issue.record("expected failed state carrying BrewLookupError.executableNotFound")
            return
        }
    }

    @Test @MainActor func `failed refresh keeps previously loaded data on screen`() async {
        let cache = InstalledInventoryCache()
        await cache.replace(
            InstalledInventorySnapshot(fetchedAt: .now, packages: [.fixture(name: "git", kind: .formula)]),
        )
        let runner = MockBrewCommandRunner(
            behaviors: [
                ["info", "--installed", "--json=v2"]: .throw(BrewCommandError.failed(exitCode: 1, stderr: "boom")),
            ],
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)

        await repo.load() // cache-first paint of git
        await repo.load(forceRefresh: true) // fetch fails — must not clobber the loaded data

        if case let .loaded(packages) = repo.state {
            #expect(packages.map(\.name) == ["git"])
        } else {
            Issue.record("expected loaded state to be preserved on refresh failure")
        }
    }

    @Test @MainActor func `command center running to idle triggers a reconcile fetch`() async {
        let commandCenter = ControllableAllPhasesCommandCenter()
        let runner = CountingInfoRunner()
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner, commandCenter: commandCenter)
        await repo.load(forceRefresh: true)
        #expect(await runner.callCount == 1)
        await waitForPhaseSubscriber(commandCenter: commandCenter)

        let opID = BrewOperationID(kind: .formula, name: "git")
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeFormula))
        await commandCenter.emitPhase(id: opID, phase: .idle)

        await expectCallCount(atLeast: 2, runner: runner)
    }

    @Test @MainActor func `command center running to failed does not trigger a reconcile fetch`() async {
        let commandCenter = ControllableAllPhasesCommandCenter()
        let runner = CountingInfoRunner()
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner, commandCenter: commandCenter)
        await repo.load(forceRefresh: true)
        #expect(await runner.callCount == 1)
        await waitForPhaseSubscriber(commandCenter: commandCenter)

        let opID = BrewOperationID(kind: .formula, name: "git")
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeFormula))
        await commandCenter.emitPhase(id: opID, phase: .failed(reason: .brewExecutableNotFound))
        await settleAsync()

        #expect(await runner.callCount == 1)
    }
}

@MainActor
private func package(named name: String, in packages: [InstalledBrewPackage]) -> InstalledBrewPackage? {
    packages.first { $0.name == name }
}

extension BrewInstalledPackagesRepositoryTests {
    @Test @MainActor
    func `load falls back to canonical names when display fields are missing or invalid`() async throws {
        let json = """
        {
          "formulae": [
            { "name": "wget", "full_name": "   ", "installed": [{ "version": "1.24.5" }] }
          ],
          "casks": [
            { "token": "visual-studio-code", "name": [], "installed": "1.99.0" },
            { "token": "docker", "name": "Docker", "installed": "4.39.0" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = await InstalledPackagesTestSupport.loadedPackages(from: repo)

        let wget = try #require(package(named: "wget", in: packages))
        #expect(wget.displayName == "wget")

        let vscode = try #require(package(named: "visual-studio-code", in: packages))
        #expect(vscode.displayName == "visual-studio-code")

        let docker = try #require(package(named: "docker", in: packages))
        #expect(docker.displayName == "Docker")
    }
}

// MARK: - Reconcile helpers

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
private func expectCallCount(atLeast target: Int, runner: CountingInfoRunner) async {
    for _ in 0 ..< 200 {
        if await runner.callCount >= target {
            return
        }
        await Task.yield()
    }
    #expect(await runner.callCount >= target)
}

/// Counts `brew info` invocations so reconcile tests can assert a fresh fetch happened.
private actor CountingInfoRunner: BrewCommandRunning {
    private(set) var callCount = 0

    func run(executableURL _: URL, arguments _: [String]) async throws -> CommandOutput {
        callCount += 1
        return CommandOutput(
            standardOutput: #"{ "formulae": [], "casks": [] }"#,
            standardError: "",
            terminationStatus: 0,
        )
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

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        false
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
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

    func outputChanges(for _: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        AsyncStream<BrewCommandOutputLine>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func submit(
        id _: BrewOperationID,
        command _: any BrewMutatingCommand,
    ) async throws {}

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
