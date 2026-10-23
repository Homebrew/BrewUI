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

    /// A real `SerialBrewCommandCenter` over a mock runner, so the preview takes the production submit path.
    private static func makeRepository(
        behaviors: [[String]: MockBrewCommandRunnerBehavior],
        locator: any BrewExecutableLocating = BrewExecutableLocator(overrideURL: brewURL),
    ) -> BrewCleanupRepository {
        let context = BrewCommandExecutionContext(commandRunner: MockBrewCommandRunner(behaviors: behaviors), locator: locator)
        let center = SerialBrewCommandCenter(executionContext: context, reconciler: NoopBrewOperationReconciler())
        return BrewCleanupRepository(commandCenter: center)
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
        let context = BrewCommandExecutionContext(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: Self.brewURL))
        let repository = BrewCleanupRepository(
            commandCenter: SerialBrewCommandCenter(executionContext: context, reconciler: NoopBrewOperationReconciler()),
        )

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: false)

        #expect(repository.state.value?.removals.count == 1 && repository.refreshFailure != nil)
    }

    @Test func `switching option does not show the other option's report`() async {
        let runner = SequencedRunner([
            .output(CommandOutput(standardOutput: "Would remove: /cache/a.tar.gz (1MB)\n", standardError: "", terminationStatus: 0)),
            .throw(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let context = BrewCommandExecutionContext(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: Self.brewURL))
        let repository = BrewCleanupRepository(
            commandCenter: SerialBrewCommandCenter(executionContext: context, reconciler: NoopBrewOperationReconciler()),
        )

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: true)

        #expect(repository.state.value == nil)
    }

    @Test func `switching option clears the other option's refresh failure`() async {
        let runner = SequencedRunner([
            .output(CommandOutput(standardOutput: "Would remove: /cache/a.tar.gz (1MB)\n", standardError: "", terminationStatus: 0)),
            .throw(BrewCommandError.launchFailed(underlying: "spawn failed")),
        ])
        let context = BrewCommandExecutionContext(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: Self.brewURL))
        let repository = BrewCleanupRepository(
            commandCenter: SerialBrewCommandCenter(executionContext: context, reconciler: NoopBrewOperationReconciler()),
        )

        await repository.load(pruneAll: false)
        await repository.load(pruneAll: false)
        await repository.load(pruneAll: true)

        #expect(repository.state.value == nil && repository.refreshFailure == nil)
    }

    @Test func `the preview runs in the console as a read-only maintenance job`() async {
        let context = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(behaviors: [Self.preview: Self.output("")]),
            locator: BrewExecutableLocator(overrideURL: Self.brewURL),
        )
        let center = RecordingSerialBrewCommandCenter(executionContext: context)
        let repository = BrewCleanupRepository(commandCenter: center)

        await repository.load(pruneAll: false)

        let entries = await center.recordedSubmitEntries
        #expect(entries.map(\.kind) == [.cleanupPreview])
        #expect(entries.first?.id == .maintenance(token: "cleanupPreview", displayCommand: "brew cleanup --dry-run"))
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
