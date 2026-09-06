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
        return BrewDoctorRepository(commandCenter: center, executionContext: context)
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

    // MARK: - Structured output

    private static let structuredJSON = """
    {"tier": 1, "findings": [
      {"text": "You have unlinked kegs in your Cellar.", "tier": 3, "affects": [], "links": [],
       "remediation": {"commands": ["brew link openssl@3"], "text": "To fix, run:\\n  brew link openssl@3\\n"}}
    ]}
    """

    private static let transcript = """
    Warning: You have unlinked kegs in your Cellar.
    Run `brew link` on these:
      openssl@3
    """

    /// One refresh, two runs: `--json` for the findings and plain `brew doctor` for the transcript.
    private static func bothRunsRunner(
        json: String = structuredJSON,
        text: String = transcript,
        jsonExitCode: Int32 = 1,
    ) -> MockBrewCommandRunner {
        MockBrewCommandRunner(responses: [
            ["doctor"]: CommandOutput(standardOutput: "", standardError: text, terminationStatus: 1),
            ["doctor", "--json"]: CommandOutput(
                standardOutput: json,
                standardError: "",
                terminationStatus: jsonExitCode,
            ),
        ])
    }

    @Test func `findings come from the JSON, not from parsing the transcript`() async {
        let repository = Self.makeRepository(runner: Self.bothRunsRunner())
        await repository.load(forceRefresh: true)

        // The transcript has no tier callout, so a text-parsed issue would be `.caution`.
        #expect(repository.state.value?.issues.first?.severity == .danger)
        #expect(repository.state.value?.issues.first?.blocks.contains { $0.isRunnable } == true)
    }

    @Test func `the raw output stays the CLI transcript rather than the JSON`() async {
        let repository = Self.makeRepository(runner: Self.bothRunsRunner())
        await repository.load(forceRefresh: true)

        let rawOutput = repository.state.value?.rawOutput ?? ""
        #expect(rawOutput.contains("Warning: You have unlinked kegs in your Cellar."))
        #expect(!rawOutput.contains("\"findings\""))
    }

    /// `brew doctor --json` exits non-zero exactly when it has findings, which must not read as a failure.
    @Test func `a non-zero exit from the JSON run is not a failure`() async {
        let repository = Self.makeRepository(runner: Self.bothRunsRunner(jsonExitCode: 1))
        await repository.load(forceRefresh: true)

        #expect(repository.state.value?.issues.count == 1)
    }

    @Test func `a brew too old for --json degrades to parsing the transcript`() async {
        let repository = Self.makeRepository(
            runner: Self.bothRunsRunner(json: "Error: invalid option: --json"),
        )
        await repository.load(forceRefresh: true)

        // Parsed from the text, so severity falls back to the untiered default rather than the JSON's.
        #expect(repository.state.value?.issues.count == 1)
        #expect(repository.state.value?.issues.first?.severity == .caution)
    }

    @Test func `a brew known not to support --json is not asked again`() async {
        let runner = ArgumentRecordingRunner(
            responses: [
                ["doctor"]: CommandOutput(standardOutput: "", standardError: Self.transcript, terminationStatus: 1),
                ["doctor", "--json"]: CommandOutput(
                    standardOutput: "Error: invalid option: --json",
                    standardError: "",
                    terminationStatus: 1,
                ),
            ],
        )
        let repository = Self.makeRepository(runner: runner)

        await repository.load(forceRefresh: true)
        await repository.load(forceRefresh: true)

        #expect(await runner.invocations.count(where: { $0 == ["doctor", "--json"] }) == 1)
        #expect(await runner.invocations.count(where: { $0 == ["doctor"] }) == 2)
    }

    /// Losing the transcript costs the raw view, not the report — the findings run is the report.
    @Test func `a failed transcript run still yields a report when the JSON run succeeded`() async {
        let repository = Self.makeRepository(runner: MockBrewCommandRunner(behaviors: [
            ["doctor"]: .throw(BrewCommandError.launchFailed(underlying: "spawn failed")),
            ["doctor", "--json"]: .output(CommandOutput(
                standardOutput: Self.structuredJSON,
                standardError: "",
                terminationStatus: 1,
            )),
        ]))
        await repository.load(forceRefresh: true)

        #expect(repository.state.value?.issues.count == 1)
        #expect(repository.state.value?.rawOutput.isEmpty == true)
    }

    // MARK: - Freshness

    /// Same wiring as ``makeRepository(runner:locator:)``, with an injected clock.
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
            commandRunner: runner,
            locator: context.locator,
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
        let repository = BrewDoctorRepository(commandCenter: center, executionContext: context)

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

    /// Only the transcript run draws from the sequence; letting the `--json` run consume a step would
    /// shift every later answer onto the wrong run.
    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        guard arguments == ["doctor"] else {
            throw BrewCommandError.failed(exitCode: 99, stderr: "unmocked: \(arguments.joined(separator: " "))")
        }
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

/// Counts plain `brew doctor` runs only, so a refresh counts once despite also spawning `--json`.
private actor CountingCommandRunner: BrewCommandRunning {
    private(set) var runCount = 0
    private let output: CommandOutput

    init(output: CommandOutput) {
        self.output = output
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        guard arguments == ["doctor"] else {
            return CommandOutput(
                standardOutput: #"{"tier": 1, "findings": [{"text": "A.", "tier": 1}]}"#,
                standardError: "",
                terminationStatus: 1,
            )
        }
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

private actor ArgumentRecordingRunner: BrewCommandRunning {
    private(set) var invocations: [[String]] = []
    private let responses: [[String]: CommandOutput]

    init(responses: [[String]: CommandOutput]) {
        self.responses = responses
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        invocations.append(arguments)
        guard let output = responses[arguments] else {
            throw BrewCommandError.failed(exitCode: 99, stderr: "unmocked: \(arguments.joined(separator: " "))")
        }
        return output
    }
}
