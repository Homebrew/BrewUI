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

    private static func repository(
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32,
    ) -> BrewDoctorRepository {
        let runner = MockBrewCommandRunner(responses: [
            ["doctor"]: CommandOutput(standardOutput: stdout, standardError: stderr, terminationStatus: exitCode),
        ])
        return BrewDoctorRepository(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: brewURL))
    }

    @Test func `healthy system reports no issues`() async {
        let repository = Self.repository(stdout: "Your system is ready to brew.\n", exitCode: 0)
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
        let repository = Self.repository(stderr: stderr, exitCode: 1)
        await repository.load()

        let issue = repository.state.value?.issues.first
        #expect(repository.state.value?.issues.count == 1)
        #expect(issue?.affectedItems == ["openssl@3"])
        #expect(issue?.inlineChips.first?.displayCommand == "brew link")
    }

    @Test func `missing brew executable leaves a failed state`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let repository = BrewDoctorRepository(commandRunner: runner, locator: MissingBrewExecutableLocator())
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
        let repository = BrewDoctorRepository(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: Self.brewURL),
        )

        await repository.load()
        #expect(repository.state.value?.issues.count == 1)

        await repository.load()
        // Still showing the first report, not blanked to .failed.
        #expect(repository.state.value?.issues.count == 1)
        #expect(repository.isRefreshing == false)
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
