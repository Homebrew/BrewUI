//
//  ConsoleViewModelTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureConsole
import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct ConsoleViewModelTests {
    @Test func `activeJob returns most recently started not-yet-terminal job`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(kind: .formula, name: "gh")
        let second = BrewOperationID(kind: .formula, name: "ripgrep")

        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        #expect(harness.viewModel.activeJob?.operationID == second)

        await harness.emit(id: second, phase: .idle)

        #expect(harness.viewModel.activeJob?.operationID == first)
    }

    @Test func `selectedJob prefers explicit selection over active or recent`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(kind: .formula, name: "gh")
        let second = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        try harness.viewModel.select(id: #require(harness.job(for: first)?.id))

        #expect(harness.viewModel.selectedJob?.operationID == first)
    }

    @Test func `selectedJob falls back to active when nothing is explicitly selected`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let running = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: running, phase: .running(.installFormula))

        #expect(harness.viewModel.selectedID == nil)
        #expect(harness.viewModel.selectedJob?.operationID == running)
    }

    @Test func `dismiss clears selection and removes the job from the repository`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        let jobID = try #require(harness.job(for: id)?.id)
        harness.viewModel.select(id: jobID)

        harness.viewModel.dismiss(id: jobID)

        #expect(harness.viewModel.selectedID == nil)
        #expect(harness.job(for: id) == nil)
    }

    @Test func `dismiss for a non-selected job leaves selection intact`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let selected = BrewOperationID(kind: .formula, name: "gh")
        let other = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: selected, phase: .running(.installFormula))
        await harness.emit(id: other, phase: .running(.installFormula))
        let selectedJobID = try #require(harness.job(for: selected)?.id)
        harness.viewModel.select(id: selectedJobID)

        try harness.viewModel.dismiss(id: #require(harness.job(for: other)?.id))

        #expect(harness.viewModel.selectedID == selectedJobID)
        #expect(harness.job(for: other) == nil)
    }

    @Test func `clearCompleted clears selection if the selected job was terminal`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, phase: .idle)
        try harness.viewModel.select(id: #require(harness.job(for: id)?.id))

        harness.viewModel.clearCompleted()

        #expect(harness.viewModel.selectedID == nil)
    }

    @Test func `clearCompleted preserves selection if the selected job is still running`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let running = BrewOperationID(kind: .formula, name: "gh")
        let done = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: running, phase: .running(.installFormula))
        await harness.emit(id: done, phase: .running(.installFormula))
        await harness.emit(id: done, phase: .idle)
        let runningJobID = try #require(harness.job(for: running)?.id)
        harness.viewModel.select(id: runningJobID)

        harness.viewModel.clearCompleted()

        #expect(harness.viewModel.selectedID == runningJobID)
    }

    // MARK: - bodyContent

    @Test func `bodyContent is the empty state until something has run`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()

        #expect(harness.viewModel.bodyContent == .noActivity)
    }

    @Test func `bodyContent carries the selected job's identity and output`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        let line = BrewCommandOutputLine(stream: .stdout, text: "==> Fetching gh")
        await harness.emit(id: id, output: line)
        let job = try #require(harness.job(for: id))

        #expect(harness.viewModel.bodyContent == .output(jobID: job.id, lines: [line]))
    }

    @Test func `bodyContent follows the selected job`() async throws {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(kind: .formula, name: "gh")
        let second = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: first, phase: .running(.installFormula))
        let line = BrewCommandOutputLine(stream: .stdout, text: "==> Fetching gh")
        await harness.emit(id: first, output: line)
        await harness.emit(id: second, phase: .running(.installFormula))
        let firstJob = try #require(harness.job(for: first))

        harness.viewModel.select(id: firstJob.id)

        #expect(harness.viewModel.bodyContent == .output(jobID: firstJob.id, lines: [line]))
    }

    // MARK: - shouldAutoExpandConsole

    @Test func `shouldAutoExpandConsole is false with no jobs`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()

        #expect(!harness.viewModel.shouldAutoExpandConsole)
    }

    @Test func `shouldAutoExpandConsole becomes true once a command starts running`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .running(.installFormula))

        #expect(harness.viewModel.shouldAutoExpandConsole)
    }

    @Test func `shouldAutoExpandConsole returns to false once the running command reaches terminal`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")

        await harness.emit(id: id, phase: .running(.installFormula))
        #expect(harness.viewModel.shouldAutoExpandConsole)

        await harness.emit(id: id, phase: .idle)
        #expect(!harness.viewModel.shouldAutoExpandConsole)
    }

    @Test func `shouldAutoExpandConsole stays true while any command is still running`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let first = BrewOperationID(kind: .formula, name: "gh")
        let second = BrewOperationID(kind: .formula, name: "ripgrep")

        await harness.emit(id: first, phase: .running(.installFormula))
        await harness.emit(id: second, phase: .running(.installFormula))

        // One finishes — the other is still running, so the panel should stay open.
        await harness.emit(id: first, phase: .idle)
        #expect(harness.viewModel.shouldAutoExpandConsole)

        // Both finished — nothing running.
        await harness.emit(id: second, phase: .idle)
        #expect(!harness.viewModel.shouldAutoExpandConsole)
    }

    @Test func `autoExpandEnabled defaults to true`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()

        #expect(harness.viewModel.autoExpandEnabled)
    }

    @Test func `shouldAutoExpandConsole is false while a command runs but auto-expand is disabled`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))

        harness.viewModel.autoExpandEnabled = false

        #expect(!harness.viewModel.shouldAutoExpandConsole)
    }

    @Test func `shouldAutoExpandConsole returns to true when auto-expand is re-enabled while a command runs`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))

        harness.viewModel.autoExpandEnabled = false
        #expect(!harness.viewModel.shouldAutoExpandConsole)

        harness.viewModel.autoExpandEnabled = true
        #expect(harness.viewModel.shouldAutoExpandConsole)
    }
}
