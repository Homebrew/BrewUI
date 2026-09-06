//
//  BrewDoctorRepositoryTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct BrewDoctorRepositoryTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    /// Wires a real `SerialBrewCommandCenter` over a mock runner so the test exercises the same submit
    /// path as production (the doctor read goes through the center, output sink and all).
    private static func makeRepository(
        runner: any BrewCommandRunning,
        locator: any BrewExecutableLocating = BrewExecutableLocator(overrideURL: brewURL),
    ) -> BrewDoctorRepository {
        let context = BrewCommandExecutionContext(commandRunner: runner, locator: locator)
        let center = SerialBrewCommandCenter(executionContext: context)
        return BrewDoctorRepository(commandCenter: center)
    }

    private static func fixedRunner(
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32,
    ) -> MockBrewCommandRunner {
        MockBrewCommandRunner(responses: [
            ["doctor"]: CommandOutput(standardOutput: stdout, standardError: stderr, terminationStatus: exitCode),
        ])
    }

    @Test func `healthy system reports no issues`() async {
        let repository = Self.makeRepository(runner: Self.fixedRunner(
            stdout: "Your system is ready to brew.\n",
            exitCode: 0,
        ))
        await repository.load(forceRefresh: true)
        #expect(repository.state.value?.isHealthy == true)
        #expect(repository.isRefreshing == false)
    }

    @Test func `warnings on stderr with nonzero exit are parsed, not thrown`() async {
        let stderr = """
        Warning: You have unlinked kegs in your Cellar.
        Run `brew link` on these:
          openssl@3
        """
        let repository = Self.makeRepository(runner: Self.fixedRunner(stderr: stderr, exitCode: 1))
        await repository.load(forceRefresh: true)

        let issue = repository.state.value?.issues.first
        #expect(repository.state.value?.issues.count == 1)
        let dataItems = issue?.blocks.flatMap { block -> [String] in
            guard case let .data(items) = block.content else {
                return []
            }
            return items
        }
        #expect(dataItems == ["openssl@3"])
    }

    @Test func `ANSI colour codes in doctor output are stripped before parsing`() async {
        // Doctor output is colourised for display, so its captured output carries ANSI codes; the parser
        // is colour-blind, so they must be stripped or block classification misfires.
        let stderr = """
        \u{1B}[31mWarning:\u{1B}[0m You have unlinked kegs in your Cellar.
        Run `brew link` on these:
          openssl@3
        """
        let repository = Self.makeRepository(runner: Self.fixedRunner(stderr: stderr, exitCode: 1))
        await repository.load(forceRefresh: true)

        let issue = repository.state.value?.issues.first
        #expect(repository.state.value?.issues.count == 1)
        let dataItems = issue?.blocks.flatMap { block -> [String] in
            guard case let .data(items) = block.content else {
                return []
            }
            return items
        }
        #expect(dataItems == ["openssl@3"])
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
            .output(CommandOutput(
                standardOutput: "",
                standardError: "Warning: You have unlinked kegs in your Cellar.\n  openssl@3",
                terminationStatus: 1,
            )),
            .failure(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let repository = Self.makeRepository(runner: runner)

        await repository.load(forceRefresh: true)
        #expect(repository.state.value?.issues.count == 1)

        await repository.load(forceRefresh: true)
        // Still showing the first report, not blanked to .failed.
        #expect(repository.state.value?.issues.count == 1)
        #expect(repository.isRefreshing == false)
    }

    // MARK: - Freshness

    /// Same wiring as ``makeRepository(runner:locator:)``, with an injected clock so a report's age can be
    /// moved without waiting an hour for it.
    private static func makeAgeableRepository(
        runner: any BrewCommandRunning,
        clock: MutableClock,
        refreshInterval: TimeInterval = 3600,
    ) -> BrewDoctorRepository {
        let context = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        return BrewDoctorRepository(
            commandCenter: SerialBrewCommandCenter(executionContext: context),
            refreshInterval: refreshInterval,
            now: clock.dateProvider,
        )
    }

    @Test func `arriving with a current report does not re-run brew doctor`() async {
        let clock = MutableClock()
        let runner = CountingCommandRunner(
            output: CommandOutput(standardOutput: "", standardError: "Warning: A\n", terminationStatus: 1),
        )
        let repository = Self.makeAgeableRepository(runner: runner, clock: clock)

        await repository.load(forceRefresh: false)
        clock.advance(by: 60)
        await repository.load(forceRefresh: false)

        #expect(await runner.runCount == 1)
    }

    @Test func `a report older than the refresh interval is re-run on arrival`() async {
        let clock = MutableClock()
        let runner = CountingCommandRunner(
            output: CommandOutput(standardOutput: "", standardError: "Warning: A\n", terminationStatus: 1),
        )
        let repository = Self.makeAgeableRepository(runner: runner, clock: clock)

        await repository.load(forceRefresh: false)
        clock.advance(by: 3600)
        await repository.load(forceRefresh: false)

        #expect(await runner.runCount == 2)
    }

    @Test func `forceRefresh re-runs a report that is still current`() async {
        let clock = MutableClock()
        let runner = CountingCommandRunner(
            output: CommandOutput(standardOutput: "", standardError: "Warning: A\n", terminationStatus: 1),
        )
        let repository = Self.makeAgeableRepository(runner: runner, clock: clock)

        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: true)

        #expect(await runner.runCount == 2)
    }

    /// A failure leaves nothing to go stale, so the next arrival must retry rather than sit on it.
    @Test func `a failed run is retried on the next arrival`() async {
        let clock = MutableClock()
        let runner = SequencedCommandRunner([
            .failure(BrewCommandError.launchFailed(underlying: "spawn failed")),
            .output(CommandOutput(standardOutput: "", standardError: "Warning: A\n", terminationStatus: 1)),
        ])
        let repository = Self.makeAgeableRepository(runner: runner, clock: clock)

        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: false)

        #expect(repository.state.value?.issues.count == 1)
    }

    @Test func `doctor read submit appears as a maintenance op kind .doctorRead`() async {
        let runner = Self.fixedRunner(stdout: "Your system is ready to brew.\n", exitCode: 0)
        let context = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: Self.brewURL),
        )
        let center = RecordingSerialBrewCommandCenter(executionContext: context)
        let repository = BrewDoctorRepository(commandCenter: center)

        await repository.load(forceRefresh: true)

        let entries = await center.recordedSubmitEntries
        #expect(entries.count == 1)
        #expect(entries.first?.kind == .doctorRead)
        #expect(entries.first?.id == .maintenance(token: "doctor", displayCommand: "brew doctor"))
    }
}

private actor SequencedCommandRunner: BrewCommandRunning {
    enum Step {
        case output(CommandOutput)
        case failure(any Error & Sendable)
    }

    private var steps: [Step]

    init(_ steps: [Step]) {
        self.steps = steps
    }

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        guard !steps.isEmpty else {
            return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
        }
        switch steps.removeFirst() {
        case let .output(output):
            return output
        case let .failure(error):
            throw error
        }
    }
}

/// Counts how many times brew was actually spawned, which is what the freshness rule is about.
private actor CountingCommandRunner: BrewCommandRunning {
    private(set) var runCount = 0
    private let output: CommandOutput

    init(output: CommandOutput) {
        self.output = output
    }

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        runCount += 1
        return output
    }
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
