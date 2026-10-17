//
//  BrewSecurityAdvisoryRepositoryTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Observation
import Testing

@MainActor
struct BrewSecurityAdvisoryRepositoryTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
    private static let arguments = ["vulns", "--json"]

    private static let findingsJSON = """
    {"findings": [{"formula": "openjpeg", "version": "2.5.4", "tag": "v2.5.4",
      "repo_url": "https://github.com/uclouvain/openjpeg",
      "vulnerabilities": [{"id": "OSV-2025-219", "severity": "HIGH", "summary": "Heap-buffer-overflow",
        "aliases": [], "fixed_versions": []}],
      "patched": []}],
     "skipped_formulae": []}
    """

    /// Wires a real `SerialBrewCommandCenter` over a fake runner, so the scan takes the production path.
    private static func makeRepository(
        runner: any BrewCommandRunning,
        locator: any BrewExecutableLocating = BrewExecutableLocator(overrideURL: brewURL),
        inventory: any InstalledInventoryObserving = MutableInventory(),
        clock: MutableClock = MutableClock(),
    ) -> BrewSecurityAdvisoryRepository {
        let context = BrewCommandExecutionContext(commandRunner: runner, locator: locator)
        let center = SerialBrewCommandCenter(executionContext: context, reconciler: NoopBrewOperationReconciler())
        return BrewSecurityAdvisoryRepository(
            commandCenter: center,
            inventory: inventory,
            refreshInterval: 3600,
            now: clock.dateProvider,
        )
    }

    private static func fixedRunner(stdout: String, stderr: String = "", exitCode: Int32) -> MockBrewCommandRunner {
        MockBrewCommandRunner(responses: [
            arguments: CommandOutput(standardOutput: stdout, standardError: stderr, terminationStatus: exitCode),
        ])
    }

    // MARK: - Outcomes

    @Test func `open advisories with a nonzero exit are parsed, not thrown`() async {
        let repository = Self.makeRepository(runner: Self.fixedRunner(stdout: Self.findingsJSON, exitCode: 1))

        await repository.load(forceRefresh: true)

        #expect(repository.state.value?.affectedPackages.map(\.package) == [.formula(name: "openjpeg")])
    }

    @Test func `stderr warnings become coverage diagnostics`() async {
        let repository = Self.makeRepository(runner: Self.fixedRunner(
            stdout: Self.findingsJSON,
            stderr: "\u{1B}[33mWarning\u{1B}[0m: 1 installed keg from an untrusted tap not scanned:\n",
            exitCode: 1,
        ))

        await repository.load(forceRefresh: true)

        #expect(repository.state.value?.coverage.diagnostics == "Warning: 1 installed keg from an untrusted tap not scanned:")
    }

    @Test func `a Homebrew without vulns fails as unsupported`() async {
        let repository = Self.makeRepository(runner: Self.fixedRunner(
            stdout: "",
            stderr: "Error: Unknown command: vulns\n",
            exitCode: 1,
        ))

        await repository.load(forceRefresh: true)

        #expect(Self.failure(of: repository) == .unsupportedBrewCommand(command: "brew vulns"))
    }

    @Test func `undecodable output with a zero exit is malformed`() async {
        let repository = Self.makeRepository(runner: Self.fixedRunner(stdout: "not json", exitCode: 0))

        await repository.load(forceRefresh: true)

        #expect(Self.failure(of: repository) == .malformedBrewOutput(command: "brew vulns --json"))
    }

    @Test func `undecodable output with a nonzero exit keeps brew's error`() async {
        let repository = Self.makeRepository(runner: Self.fixedRunner(
            stdout: "",
            stderr: "Error: OSV API request failed",
            exitCode: 1,
        ))

        await repository.load(forceRefresh: true)

        guard case let .failed(error) = repository.state,
              case let BrewCommandError.failed(_, stderr) = error
        else {
            Issue.record("expected a brew command failure, got \(repository.state)")
            return
        }
        #expect(stderr == "Error: OSV API request failed")
    }

    @Test func `missing brew executable leaves a failed state`() async {
        let repository = Self.makeRepository(
            runner: MockBrewCommandRunner(responses: [:]),
            locator: MissingBrewExecutableLocator(),
        )

        await repository.load(forceRefresh: true)

        if case .failed = repository.state {
            // expected
        } else {
            Issue.record("expected .failed state, got \(repository.state)")
        }
    }

    @Test func `a failed refresh keeps the prior report on screen`() async {
        let runner = SequencedCommandRunner([
            .output(CommandOutput(standardOutput: Self.findingsJSON, standardError: "", terminationStatus: 1)),
            .failure(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let repository = Self.makeRepository(runner: runner)

        await repository.load(forceRefresh: true)
        await repository.load(forceRefresh: true)

        #expect(repository.state.value?.affectedPackages.count == 1)
    }

    // MARK: - Freshness

    @Test func `arriving with a current report does not rescan`() async {
        let clock = MutableClock()
        let runner = SequencedCommandRunner([])
        let repository = Self.makeRepository(runner: runner, clock: clock)

        await repository.load(forceRefresh: false)
        clock.advance(by: 60)
        await repository.load(forceRefresh: false)

        #expect(await runner.runCount == 1)
    }

    @Test func `a report older than the refresh interval is rescanned`() async {
        let clock = MutableClock()
        let runner = SequencedCommandRunner([])
        let repository = Self.makeRepository(runner: runner, clock: clock)

        await repository.load(forceRefresh: false)
        clock.advance(by: 3600)
        await repository.load(forceRefresh: false)

        #expect(await runner.runCount == 2)
    }

    @Test func `a change to the installed formulae makes the report stale`() async {
        let inventory = MutableInventory(packages: [.fixture(name: "openjpeg", installedVersions: ["2.5.4"])])
        let runner = SequencedCommandRunner([])
        let repository = Self.makeRepository(runner: runner, inventory: inventory)

        await repository.load(forceRefresh: false)
        inventory.packages = [.fixture(name: "openjpeg", installedVersions: ["2.5.5"])]
        await repository.load(forceRefresh: false)

        #expect(await runner.runCount == 2)
    }

    @Test func `a cask change does not make the report stale`() async {
        let inventory = MutableInventory()
        let runner = SequencedCommandRunner([])
        let repository = Self.makeRepository(runner: runner, inventory: inventory)

        await repository.load(forceRefresh: false)
        inventory.packages = [.fixture(name: "iterm2", kind: .cask, installedVersions: ["3.5"])]
        await repository.load(forceRefresh: false)

        #expect(await runner.runCount == 1)
    }

    @Test func `concurrent loads share one scan`() async {
        let runner = SequencedCommandRunner([])
        let repository = Self.makeRepository(runner: runner)

        async let first: Void = repository.load(forceRefresh: true)
        async let second: Void = repository.load(forceRefresh: true)
        _ = await (first, second)

        #expect(await runner.runCount == 1)
    }

    @Test func `a scan appears as a read-only maintenance operation`() async {
        let runner = Self.fixedRunner(stdout: Self.findingsJSON, exitCode: 1)
        let context = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: Self.brewURL),
        )
        let center = RecordingSerialBrewCommandCenter(executionContext: context)
        let repository = BrewSecurityAdvisoryRepository(commandCenter: center, inventory: MutableInventory())

        await repository.load(forceRefresh: true)

        let entries = await center.recordedSubmitEntries
        #expect(entries.map(\.kind) == [.vulnsRead])
        #expect(entries.first?.id == .maintenance(token: "vulns", displayCommand: "brew vulns"))
    }

    private static func failure(of repository: BrewSecurityAdvisoryRepository) -> BrewRepositoryError? {
        guard case let .failed(error) = repository.state else {
            return nil
        }
        return error as? BrewRepositoryError
    }
}

/// Answers `brew vulns --json` from a queue, then with an empty scan, counting every run.
private actor SequencedCommandRunner: BrewCommandRunning {
    enum Step {
        case output(CommandOutput)
        case failure(any Error & Sendable)
    }

    private var steps: [Step]
    private(set) var runCount = 0

    init(_ steps: [Step]) {
        self.steps = steps
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        guard arguments == ["vulns", "--json"] else {
            throw BrewCommandError.failed(exitCode: 99, stderr: "unmocked: \(arguments.joined(separator: " "))")
        }
        runCount += 1
        guard !steps.isEmpty else {
            return CommandOutput(
                standardOutput: #"{"findings": [], "skipped_formulae": []}"#,
                standardError: "",
                terminationStatus: 0,
            )
        }
        switch steps.removeFirst() {
        case let .output(output):
            return output
        case let .failure(error):
            throw error
        }
    }
}

/// Installed inventory the test can change between scans.
@Observable
@MainActor
private final class MutableInventory: InstalledInventoryObserving {
    var packages: [InstalledBrewPackage]
    let refreshFailure: (any Error)? = nil

    init(packages: [InstalledBrewPackage] = []) {
        self.packages = packages
    }

    var state: LoadState<[InstalledBrewPackage], any Error> {
        .loaded(packages)
    }

    func load(forceRefresh _: Bool) async {}
}

/// Hand-wound clock so a report's age can be moved forward without sleeping.
@MainActor
private final class MutableClock {
    private(set) var now = Date(timeIntervalSince1970: 1_000_000)

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }

    nonisolated var dateProvider: @Sendable () -> Date {
        // The repository is @MainActor; the synchronous @Sendable closure type can't say so.
        // swiftlint:disable:next assume_isolated
        { MainActor.assumeIsolated { self.now } }
    }
}
