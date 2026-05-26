//
//  JobRegistryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct JobRegistryTests {
    @Test func `running phase for unknown id materializes a job`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")

        registry.handlePhase(id: id, phase: .running(.installFormula))

        #expect(registry.jobs[id] != nil)
        #expect(registry.orderedIDs == [id])
        #expect(registry.jobs[id]?.command == "brew install gh")
    }

    @Test func `idle phase for unknown id is ignored (initial replay artifact)`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")

        registry.handlePhase(id: id, phase: .idle)

        #expect(registry.jobs.isEmpty)
        #expect(registry.orderedIDs.isEmpty)
    }

    @Test func `subsequent transition to idle marks the job terminal and succeeded`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")

        registry.handlePhase(id: id, phase: .running(.installFormula))
        registry.handlePhase(id: id, phase: .idle)

        let job = registry.jobs[id]
        #expect(job?.isTerminal == true)
        #expect(job?.succeeded == true)
    }

    @Test func `activeJob returns most recently started not-yet-terminal job`() {
        let registry = JobRegistry()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")

        registry.handlePhase(id: first, phase: .running(.installFormula))
        registry.handlePhase(id: second, phase: .running(.installFormula))

        #expect(registry.activeJob?.id == second)

        registry.handlePhase(id: second, phase: .idle)

        #expect(registry.activeJob?.id == first)
    }

    @Test func `selectedJob prefers explicit selection over active or recent`() {
        let registry = JobRegistry()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")
        registry.handlePhase(id: first, phase: .running(.installFormula))
        registry.handlePhase(id: second, phase: .running(.installFormula))

        registry.selectedID = first

        #expect(registry.selectedJob?.id == first)
    }

    @Test func `jobs(for packageName:) filters by package scope`() {
        let registry = JobRegistry()
        let ghID = BrewOperationID(rawValue: "formula:gh")
        let rgID = BrewOperationID(rawValue: "formula:ripgrep")
        registry.handlePhase(id: ghID, phase: .running(.installFormula))
        registry.handlePhase(id: rgID, phase: .running(.installFormula))

        let ghJobs = registry.jobs(for: "gh")

        #expect(ghJobs.count == 1)
        #expect(ghJobs.first?.id == ghID)
    }

    @Test func `clearCompleted removes terminal jobs but preserves in-flight`() {
        let registry = JobRegistry()
        let done = BrewOperationID(rawValue: "formula:gh")
        let running = BrewOperationID(rawValue: "formula:ripgrep")
        registry.handlePhase(id: done, phase: .running(.installFormula))
        registry.handlePhase(id: done, phase: .idle)
        registry.handlePhase(id: running, phase: .running(.installFormula))

        registry.clearCompleted()

        #expect(registry.jobs[done] == nil)
        #expect(registry.jobs[running] != nil)
        #expect(registry.orderedIDs == [running])
    }

    @Test func `clearCompleted clears selection if selected job was terminal`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")
        registry.handlePhase(id: id, phase: .running(.installFormula))
        registry.handlePhase(id: id, phase: .idle)
        registry.selectedID = id

        registry.clearCompleted()

        #expect(registry.selectedID == nil)
    }
}
