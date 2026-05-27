//
//  BrewCommandJobsRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct BrewCommandJobsRepositoryTests {
    @Test func `running phase for unknown id materializes a job`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let id = BrewOperationID(rawValue: "formula:gh")

        repository.handlePhase(id: id, phase: .running(.installFormula))

        #expect(repository.jobs[id] != nil)
        #expect(repository.orderedIDs == [id])
        #expect(repository.jobs[id]?.command == "brew install gh")
    }

    @Test func `idle phase for unknown id is ignored (initial replay artifact)`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let id = BrewOperationID(rawValue: "formula:gh")

        repository.handlePhase(id: id, phase: .idle)

        #expect(repository.jobs.isEmpty)
        #expect(repository.orderedIDs.isEmpty)
    }

    @Test func `subsequent transition to idle marks the job terminal and succeeded`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let id = BrewOperationID(rawValue: "formula:gh")

        repository.handlePhase(id: id, phase: .running(.installFormula))
        repository.handlePhase(id: id, phase: .idle)

        let job = repository.jobs[id]
        #expect(job?.isTerminal == true)
        #expect(job?.succeeded == true)
    }

    @Test func `clearCompleted removes terminal jobs but preserves in-flight`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let done = BrewOperationID(rawValue: "formula:gh")
        let running = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: done, phase: .running(.installFormula))
        repository.handlePhase(id: done, phase: .idle)
        repository.handlePhase(id: running, phase: .running(.installFormula))

        repository.clearCompleted()

        #expect(repository.jobs[done] == nil)
        #expect(repository.jobs[running] != nil)
        #expect(repository.orderedIDs == [running])
    }

    @Test func `remove drops a single job and prunes orderedIDs`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: first, phase: .running(.installFormula))
        repository.handlePhase(id: second, phase: .running(.installFormula))

        repository.remove(id: first)

        #expect(repository.jobs[first] == nil)
        #expect(repository.jobs[second] != nil)
        #expect(repository.orderedIDs == [second])
    }

    @Test func `remove for unknown id is a no-op`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let known = BrewOperationID(rawValue: "formula:gh")
        let unknown = BrewOperationID(rawValue: "formula:never-running")
        repository.handlePhase(id: known, phase: .running(.installFormula))

        repository.remove(id: unknown)

        #expect(repository.jobs[known] != nil)
        #expect(repository.orderedIDs == [known])
    }

    @Test func `handleOutput appends to the matching job's output buffer`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let id = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: id, phase: .running(.installFormula))

        repository.handleOutput(id: id, line: BrewCommandOutputLine(stream: .stdout, text: "==> fetching"))
        repository.handleOutput(id: id, line: BrewCommandOutputLine(stream: .stderr, text: "warn"))

        let job = repository.jobs[id]
        #expect(job?.output.count == 2)
        #expect(job?.output[0].text == "==> fetching")
        #expect(job?.output[1].stream == .stderr)
    }

    @Test func `handleOutput for unknown id is silently dropped`() {
        let repository = BrewCommandJobsRepository.placeholder()
        let id = BrewOperationID(rawValue: "formula:never-running")

        repository.handleOutput(id: id, line: BrewCommandOutputLine(stream: .stdout, text: "orphan"))

        #expect(repository.jobs.isEmpty)
        #expect(repository.orderedIDs.isEmpty)
    }
}
