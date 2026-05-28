//
//  BrewCommandJobsRepositoryTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewNetworking
import BrewRepositories
@testable import BrewRepositoriesLive
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct BrewCommandJobsRepositoryTests {
    @Test func `running phase for unknown id materializes a job`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .running(.installFormula))

        #expect(harness.repository.jobs[id] != nil)
        #expect(harness.repository.orderedIDs == [id])
        #expect(harness.repository.jobs[id]?.command == "brew install gh")
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

        let job = harness.repository.jobs[id]
        #expect(job?.isTerminal == true)
        #expect(job?.succeeded == true)
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

        #expect(harness.repository.jobs[done] == nil)
        #expect(harness.repository.jobs[running] != nil)
        #expect(harness.repository.orderedIDs == [running])
    }

    @Test func `remove drops a single job and prunes orderedIDs`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(kind: .formula, name: "gh")
        let second = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        harness.repository.remove(id: first)

        #expect(harness.repository.jobs[first] == nil)
        #expect(harness.repository.jobs[second] != nil)
        #expect(harness.repository.orderedIDs == [second])
    }

    @Test func `remove for unknown id is a no-op`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let known = BrewOperationID(kind: .formula, name: "gh")
        let unknown = BrewOperationID(kind: .formula, name: "never-running")
        await harness.emit(id: known, phase: .running(.installFormula))

        harness.repository.remove(id: unknown)

        #expect(harness.repository.jobs[known] != nil)
        #expect(harness.repository.orderedIDs == [known])
    }

    @Test func `streamed output appends to the matching job's output buffer`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))

        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stdout, text: "==> fetching"))
        await harness.emit(id: id, output: BrewCommandOutputLine(stream: .stderr, text: "warn"))

        let job = harness.repository.jobs[id]
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
