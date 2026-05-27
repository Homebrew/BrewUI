//
//  ConsoleStatusPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct ConsoleStatusPresentationTests {
    @Test func `empty repository presents idle`() {
        let (_, viewModel) = makeFixture()

        let presentation = viewModel.statusPresentation

        #expect(presentation.dotState == .idle)
        #expect(presentation.summary == .idle)
        #expect(!presentation.isRunning)
    }

    @Test func `active job presents running with the job command and short label`() {
        let (repository, viewModel) = makeFixture()
        let id = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: id, phase: .running(.installFormula))

        let presentation = viewModel.statusPresentation

        #expect(presentation.dotState == .running)
        #expect(presentation.summary == .running(command: "brew install gh", shortLabel: "running"))
        #expect(presentation.isRunning)
    }

    @Test func `succeeded terminal job presents green dot and done summary`() {
        let (repository, viewModel) = makeFixture()
        let id = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: id, phase: .running(.installFormula))
        repository.handlePhase(id: id, phase: .idle)

        let presentation = viewModel.statusPresentation

        #expect(presentation.dotState == .succeeded)
        #expect(presentation.summary == .completed(command: "brew install gh", succeeded: true, exitCode: 0))
        #expect(!presentation.isRunning)
    }

    @Test func `failed terminal job presents red dot and exit code summary`() {
        let (repository, viewModel) = makeFixture()
        let id = BrewOperationID(rawValue: "formula:gh")
        repository.handlePhase(id: id, phase: .running(.installFormula))
        repository.handlePhase(id: id, phase: .failed(reason: .brewCommand(exitCode: 9, stderr: "nope")))

        let presentation = viewModel.statusPresentation

        #expect(presentation.dotState == .failed)
        #expect(presentation.summary == .completed(command: "brew install gh", succeeded: false, exitCode: 9))
        #expect(!presentation.isRunning)
    }

    @Test func `active job is preferred over recent completed`() {
        let (repository, viewModel) = makeFixture()
        let done = BrewOperationID(rawValue: "formula:gh")
        let running = BrewOperationID(rawValue: "formula:ripgrep")
        repository.handlePhase(id: done, phase: .running(.installFormula))
        repository.handlePhase(id: done, phase: .idle)
        repository.handlePhase(id: running, phase: .running(.installFormula))

        let presentation = viewModel.statusPresentation

        #expect(presentation.dotState == .running)
        if case let .running(command, _) = presentation.summary {
            #expect(command == "brew install ripgrep")
        } else {
            Issue.record("expected running summary")
        }
    }

    private func makeFixture() -> (BrewCommandJobsRepository, ConsoleViewModel) {
        let repository = BrewCommandJobsRepository.placeholder()
        return (repository, ConsoleViewModel(repository: repository))
    }
}

struct BrewOperationPhaseShortLabelTests {
    @Test func `idle short label is 'done'`() {
        #expect(BrewOperationPhase.idle.shortLabel == "done")
    }

    @Test func `running short label is 'running'`() {
        #expect(BrewOperationPhase.running(.installFormula).shortLabel == "running")
    }

    @Test func `failed short label is 'failed'`() {
        #expect(BrewOperationPhase.failed(reason: .brewExecutableNotFound).shortLabel == "failed")
    }
}
