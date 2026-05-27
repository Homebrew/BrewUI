//
//  ConsoleViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct ConsoleViewModelTests {
    @Test func `activeJob returns most recently started not-yet-terminal job`() {
        let (repository, viewModel) = makeFixture()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")

        repository.handlePhase(id: first, phase: .running(.installFormula))
        repository.handlePhase(id: second, phase: .running(.installFormula))

        #expect(viewModel.activeJob?.id == second)

        repository.handlePhase(id: second, phase: .idle)

        #expect(viewModel.activeJob?.id == first)
    }

    @Test func `selectedJob prefers explicit selection over active or recent`() {
        let (repository, viewModel) = makeFixture()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: first, phase: .running(.installFormula))
        repository.handlePhase(id: second, phase: .running(.installFormula))

        viewModel.select(id: first)

        #expect(viewModel.selectedJob?.id == first)
    }

    @Test func `selectedJob falls back to active when nothing is explicitly selected`() {
        let (repository, viewModel) = makeFixture()
        let running = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: running, phase: .running(.installFormula))

        #expect(viewModel.selectedID == nil)
        #expect(viewModel.selectedJob?.id == running)
    }

    @Test func `jobs(for packageName:) filters by package scope`() {
        let (repository, viewModel) = makeFixture()
        let ghID = BrewOperationID(rawValue: "formula:gh")
        let rgID = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: ghID, phase: .running(.installFormula))
        repository.handlePhase(id: rgID, phase: .running(.installFormula))

        let ghJobs = viewModel.jobs(for: "gh")

        #expect(ghJobs.count == 1)
        #expect(ghJobs.first?.id == ghID)
    }

    @Test func `dismiss clears selection and removes the job from the repository`() {
        let (repository, viewModel) = makeFixture()
        let id = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: id, phase: .running(.installFormula))
        viewModel.select(id: id)

        viewModel.dismiss(id: id)

        #expect(viewModel.selectedID == nil)
        #expect(repository.jobs[id] == nil)
    }

    @Test func `dismiss for a non-selected job leaves selection intact`() {
        let (repository, viewModel) = makeFixture()
        let selected = BrewOperationID(rawValue: "formula:gh")
        let other = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: selected, phase: .running(.installFormula))
        repository.handlePhase(id: other, phase: .running(.installFormula))
        viewModel.select(id: selected)

        viewModel.dismiss(id: other)

        #expect(viewModel.selectedID == selected)
        #expect(repository.jobs[other] == nil)
    }

    @Test func `clearCompleted clears selection if the selected job was terminal`() {
        let (repository, viewModel) = makeFixture()
        let id = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: id, phase: .running(.installFormula))
        repository.handlePhase(id: id, phase: .idle)
        viewModel.select(id: id)

        viewModel.clearCompleted()

        #expect(viewModel.selectedID == nil)
    }

    @Test func `clearCompleted preserves selection if the selected job is still running`() {
        let (repository, viewModel) = makeFixture()
        let running = BrewOperationID(rawValue: "formula:gh")
        let done = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: running, phase: .running(.installFormula))
        repository.handlePhase(id: done, phase: .running(.installFormula))
        repository.handlePhase(id: done, phase: .idle)
        viewModel.select(id: running)

        viewModel.clearCompleted()

        #expect(viewModel.selectedID == running)
    }

    private func makeFixture() -> (BrewCommandJobsRepository, ConsoleViewModel) {
        let repository = BrewCommandJobsRepository.placeholder()
        return (repository, ConsoleViewModel(repository: repository))
    }
}
