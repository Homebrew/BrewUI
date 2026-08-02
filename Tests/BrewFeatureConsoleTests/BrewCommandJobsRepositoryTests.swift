//
//  BrewCommandJobsRepositoryTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureConsole
@testable import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct BrewCommandJobsRepositoryTests {
    @Test func `running phase for unknown id materializes a job`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .running(.installFormula))

        #expect(harness.job(for: id) != nil)
        #expect(harness.orderedOperationIDs == [id])
        #expect(harness.job(for: id)?.command == "brew install gh")
    }

    @Test func `idle phase for unknown id is ignored (initial replay artifact)`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .idle)

        #expect(harness.repository.jobs.isEmpty)
        #expect(harness.repository.orderedIDs.isEmpty)
    }

    @Test func `subsequent transition to idle marks the job terminal and succeeded`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, phase: .idle)

        let job = harness.job(for: id)
        #expect(job?.isTerminal == true)
        #expect(job?.succeeded == true)
    }

    @Test func `re-running an operation after it finishes opens a separate tab`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        // The command center reuses one BrewOperationID per package across operations.
        let id = BrewOperationID(kind: .formula, name: "gh")

        // Install runs to completion...
        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stdout, text: "Pouring gh"))
        await harness.emit(id: id, phase: .idle)

        // ...then the same package is uninstalled under the same operation id.
        await harness.emit(id: id, phase: .running(.uninstallFormula))
        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stdout, text: "Uninstalling gh"))

        // Two distinct tabs, each with its own command and output — not one reused tab.
        #expect(harness.repository.orderedIDs.count == 2)
        let jobs = harness.repository.orderedIDs.compactMap { harness.repository.jobs[$0] }
        #expect(jobs.map(\.command) == ["brew install gh", "brew uninstall gh"])
        #expect(jobs.first?.output.map(\.text) == ["Pouring gh"])
        #expect(jobs.last?.output.map(\.text) == ["Uninstalling gh"])
        #expect(jobs.first?.isTerminal == true)
        #expect(jobs.last?.isTerminal == false)
    }

    @Test func `output arriving after a job finishes still lands on that finished job`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, phase: .idle)
        // Phase and output ride separate streams with no cross-stream ordering, so a trailing output
        // line can be observed after the terminal phase. It must still land on the finished run, not be
        // dropped for want of a routing entry — routing stays put until the next `.running` reuses the id.
        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stdout, text: "==> Summary"))

        let job = harness.job(for: id)
        #expect(job?.isTerminal == true)
        #expect(job?.output.map(\.text) == ["==> Summary"])
        #expect(harness.repository.orderedIDs.count == 1)
    }

    @Test func `clearCompleted removes terminal jobs but preserves in-flight`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let done = BrewOperationID(kind: .formula, name: "gh")
        let running = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: done, phase: .running(.installFormula))
        await harness.emit(id: done, phase: .idle)
        await harness.emit(id: running, phase: .running(.installFormula))

        harness.repository.clearCompleted()

        #expect(harness.job(for: done) == nil)
        #expect(harness.job(for: running) != nil)
        #expect(harness.orderedOperationIDs == [running])
    }

    @Test func `remove drops a single job and prunes orderedIDs`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(kind: .formula, name: "gh")
        let second = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        try harness.repository.remove(id: #require(harness.job(for: first)?.id))

        #expect(harness.job(for: first) == nil)
        #expect(harness.job(for: second) != nil)
        #expect(harness.orderedOperationIDs == [second])
    }

    @Test func `remove for unknown id is a no-op`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let known = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: known, phase: .running(.installFormula))

        // A tab id that was never materialized — removing it must be a no-op.
        harness.repository.remove(id: CommandJobID())

        #expect(harness.job(for: known) != nil)
        #expect(harness.orderedOperationIDs == [known])
    }

    @Test func `streamed output appends to the matching job's output buffer`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))

        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stdout, text: "==> fetching"))
        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stderr, text: "warn"))

        let job = harness.job(for: id)
        #expect(job?.output.count == 2)
        #expect(job?.output[0].text == "==> fetching")
        #expect(job?.output[1].stream == .stderr)
    }

    @Test func `streamed output for unknown id is silently dropped`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "never-running")

        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stdout, text: "orphan"))

        #expect(harness.repository.jobs.isEmpty)
        #expect(harness.repository.orderedIDs.isEmpty)
    }
}
