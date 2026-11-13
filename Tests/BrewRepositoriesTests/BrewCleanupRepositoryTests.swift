//
//  BrewCleanupRepositoryTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct BrewCleanupRepositoryTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
    private static let preview = ["cleanup", "--dry-run"]
    private static let pruneAllPreview = ["cleanup", "--dry-run", "--prune=all"]

    private static func makeRepository(
        behaviors: [[String]: MockBrewCommandRunnerBehavior],
        locator: any BrewExecutableLocating = BrewExecutableLocator(overrideURL: brewURL),
    ) -> BrewCleanupRepository {
        BrewCleanupRepository(commandRunner: MockBrewCommandRunner(behaviors: behaviors), locator: locator)
    }

    private static func makeRepository(runner: SequencedRunner) -> BrewCleanupRepository {
        BrewCleanupRepository(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: brewURL))
    }

    private static func output(_ stdout: String, stderr: String = "", exitCode: Int32 = 0) -> MockBrewCommandRunnerBehavior {
        .output(CommandOutput(standardOutput: stdout, standardError: stderr, terminationStatus: exitCode))
    }

    @Test func `a dry run is parsed into a report`() async {
        let repository = Self.makeRepository(behaviors: [
            Self.preview: Self.output("""
            Would remove: /cache/a.tar.gz (1MB)
            ==> This operation would free approximately 1MB of disk space.
            """),
        ])

        await repository.load(pruneAll: false)

        #expect(repository.state.value?.reclaimableSpace == "1MB")
    }

    @Test func `prune all previews with --prune=all`() async {
        let repository = Self.makeRepository(behaviors: [
            Self.pruneAllPreview: Self.output("Would remove: /cache/old.tar.gz (2MB)\n"),
        ])

        await repository.load(pruneAll: true)

        #expect(repository.state.value?.removals.map(\.path) == ["/cache/old.tar.gz"])
    }

    @Test func `a non-zero exit fails with Homebrew's stderr`() async {
        let repository = Self.makeRepository(behaviors: [
            Self.preview: Self.output("", stderr: "Error: Another active Homebrew process is already in progress.", exitCode: 1),
        ])

        await repository.load(pruneAll: false)

        guard case let .failed(error) = repository.state else {
            Issue.record("expected .failed, got \(repository.state)")
            return
        }
        #expect(error as? BrewCommandError == .failed(
            exitCode: 1,
            stderr: "Error: Another active Homebrew process is already in progress.",
        ))
    }

    @Test func `missing brew leaves a failed state`() async {
        let repository = Self.makeRepository(behaviors: [:], locator: MissingBrewExecutableLocator())

        await repository.load(pruneAll: false)

        #expect(repository.state.value == nil)
    }

    @Test func `a failed refresh keeps the prior report and records the failure`() async {
        let runner = SequencedRunner([
            .output(CommandOutput(standardOutput: "Would remove: /cache/a.tar.gz (1MB)\n", standardError: "", terminationStatus: 0)),
            .throw(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let repository = Self.makeRepository(runner: runner)

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: false)

        #expect(repository.state.value?.removals.count == 1 && repository.refreshFailure != nil)
    }

    @Test func `a successful refresh after a failed one clears the failure`() async {
        let success = MockBrewCommandRunnerBehavior.output(CommandOutput(
            standardOutput: "Would remove: /cache/a.tar.gz (1MB)\n",
            standardError: "",
            terminationStatus: 0,
        ))
        let recovered = MockBrewCommandRunnerBehavior.output(CommandOutput(
            standardOutput: "Would remove: /cache/b.tar.gz (2MB)\n",
            standardError: "",
            terminationStatus: 0,
        ))
        let runner = SequencedRunner([success, .throw(BrewCommandError.launchFailed(underlying: "spawn failed")), recovered])
        let repository = Self.makeRepository(runner: runner)

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: false)
        await repository.load(pruneAll: false)

        #expect(repository.state.value?.removals.map(\.path) == ["/cache/b.tar.gz"] && repository.refreshFailure == nil)
    }

    @Test func `switching option does not show the other option's report`() async {
        let runner = SequencedRunner([
            .output(CommandOutput(standardOutput: "Would remove: /cache/a.tar.gz (1MB)\n", standardError: "", terminationStatus: 0)),
            .throw(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let repository = Self.makeRepository(runner: runner)

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: true)

        #expect(repository.state.value == nil)
    }

    @Test func `switching option clears the other option's refresh failure`() async {
        let runner = SequencedRunner([
            .output(CommandOutput(standardOutput: "Would remove: /cache/a.tar.gz (1MB)\n", standardError: "", terminationStatus: 0)),
            .throw(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let repository = Self.makeRepository(runner: runner)

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: false)
        await repository.load(pruneAll: true)

        #expect(repository.state.value == nil && repository.refreshFailure == nil)
    }

    @Test func `calls waiting for the other option share one preview`() async {
        let runner = GatedRunner()
        let repository = BrewCleanupRepository(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: Self.brewURL))
        let loads = [false, true, true].map { pruneAll in
            Task { await repository.load(pruneAll: pruneAll) }
        }
        var started = runner.firstRunStarted.makeAsyncIterator()
        _ = await started.next()
        await runner.release()
        for load in loads {
            await load.value
        }

        #expect(await runner.runs == [Self.preview, Self.pruneAllPreview])
    }
}

/// Holds the first run until released and records the arguments of every run.
private actor GatedRunner: BrewCommandRunning {
    private(set) var runs: [[String]] = []
    nonisolated let firstRunStarted: AsyncStream<Void>
    private let firstRunStartedContinuation: AsyncStream<Void>.Continuation
    private var gate: CheckedContinuation<Void, Never>?

    init() {
        (firstRunStarted, firstRunStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        runs.append(arguments)
        if runs.count == 1 {
            firstRunStartedContinuation.yield()
            await withCheckedContinuation { gate = $0 }
        }
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

/// Answers each run with the next step, repeating the last one.
private actor SequencedRunner: BrewCommandRunning {
    private var steps: [MockBrewCommandRunnerBehavior]

    init(_ steps: [MockBrewCommandRunnerBehavior]) {
        self.steps = steps
    }

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        let step = steps.count > 1 ? steps.removeFirst() : steps[0]
        switch step {
        case let .output(output):
            return output
        case let .throw(error):
            throw error
        }
    }
}
