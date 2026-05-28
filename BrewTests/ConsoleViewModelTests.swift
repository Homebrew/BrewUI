//
//  ConsoleViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct ConsoleViewModelTests {
    @Test func `activeJob returns most recently started not-yet-terminal job`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")

        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        #expect(harness.viewModel.activeJob?.id == second)

        await harness.emit(id: second, phase: .idle)

        #expect(harness.viewModel.activeJob?.id == first)
    }

    @Test func `selectedJob prefers explicit selection over active or recent`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(rawValue: "formula:gh")
        let second = BrewOperationID(rawValue: "formula:ripgrep")
        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        harness.viewModel.select(id: first)

        #expect(harness.viewModel.selectedJob?.id == first)
    }

    @Test func `selectedJob falls back to active when nothing is explicitly selected`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let running = BrewOperationID(rawValue: "formula:gh")
        await harness.emit(id: running, phase: .running(.installFormula))

        #expect(harness.viewModel.selectedID == nil)
        #expect(harness.viewModel.selectedJob?.id == running)
    }

    @Test func `dismiss clears selection and removes the job from the repository`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(rawValue: "formula:gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        harness.viewModel.select(id: id)

        harness.viewModel.dismiss(id: id)

        #expect(harness.viewModel.selectedID == nil)
        #expect(harness.repository.jobs[id] == nil)
    }

    @Test func `dismiss for a non-selected job leaves selection intact`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let selected = BrewOperationID(rawValue: "formula:gh")
        let other = BrewOperationID(rawValue: "formula:ripgrep")
        await harness.emit(id: selected, phase: .running(.installFormula))
        await harness.emit(id: other, phase: .running(.installFormula))
        harness.viewModel.select(id: selected)

        harness.viewModel.dismiss(id: other)

        #expect(harness.viewModel.selectedID == selected)
        #expect(harness.repository.jobs[other] == nil)
    }

    @Test func `clearCompleted clears selection if the selected job was terminal`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(rawValue: "formula:gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, phase: .idle)
        harness.viewModel.select(id: id)

        harness.viewModel.clearCompleted()

        #expect(harness.viewModel.selectedID == nil)
    }

    @Test func `clearCompleted preserves selection if the selected job is still running`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let running = BrewOperationID(rawValue: "formula:gh")
        let done = BrewOperationID(rawValue: "formula:ripgrep")
        await harness.emit(id: running, phase: .running(.installFormula))
        await harness.emit(id: done, phase: .running(.installFormula))
        await harness.emit(id: done, phase: .idle)
        harness.viewModel.select(id: running)

        harness.viewModel.clearCompleted()

        #expect(harness.viewModel.selectedID == running)
    }
}
