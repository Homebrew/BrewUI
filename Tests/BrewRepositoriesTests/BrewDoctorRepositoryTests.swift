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
        await repository.load()
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
        await repository.load()

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
        await repository.load()

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

        await repository.load()
        #expect(repository.state.value?.issues.count == 1)

        await repository.load()
        // Still showing the first report, not blanked to .failed.
        #expect(repository.state.value?.issues.count == 1)
        #expect(repository.isRefreshing == false)
    }

    @Test func `doctor read submit appears as a maintenance op kind .doctorRead`() async {
        let runner = Self.fixedRunner(stdout: "Your system is ready to brew.\n", exitCode: 0)
        let context = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: Self.brewURL),
        )
        let center = RecordingSerialBrewCommandCenter(executionContext: context)
        let repository = BrewDoctorRepository(commandCenter: center)

        await repository.load()

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

    func run(executableURL _: URL, arguments _: [String]) async throws -> CommandOutput {
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
