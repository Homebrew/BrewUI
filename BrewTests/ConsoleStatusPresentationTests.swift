//
//  ConsoleStatusPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct ConsoleStatusPresentationTests {
    @Test func `empty repository presents idle`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()

        let presentation = harness.viewModel.statusPresentation

        #expect(presentation.dotState == .idle)
        #expect(presentation.summary == .idle)
        #expect(!presentation.isRunning)
    }

    @Test func `active job presents running with the job command and short label`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))

        let presentation = harness.viewModel.statusPresentation

        #expect(presentation.dotState == .running)
        #expect(presentation.summary == .running(command: "brew install gh", shortLabel: "running"))
        #expect(presentation.isRunning)
    }

    @Test func `succeeded terminal job presents green dot and done summary`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, phase: .idle)

        let presentation = harness.viewModel.statusPresentation

        #expect(presentation.dotState == .succeeded)
        #expect(presentation.summary == .completed(command: "brew install gh", succeeded: true, exitCode: 0))
        #expect(!presentation.isRunning)
    }

    @Test func `failed terminal job presents red dot and exit code summary`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let id = BrewOperationID(kind: .formula, name: "gh")
        await harness.emit(id: id, phase: .running(.installFormula))
        await harness.emit(id: id, phase: .failed(reason: .brewCommand(exitCode: 9, stderr: "nope")))

        let presentation = harness.viewModel.statusPresentation

        #expect(presentation.dotState == .failed)
        #expect(presentation.summary == .completed(command: "brew install gh", succeeded: false, exitCode: 9))
        #expect(!presentation.isRunning)
    }

    @Test func `active job is preferred over recent completed`() async {
        let harness = ConsoleJobsHarness()
        await harness.awaitReady()
        let done = BrewOperationID(kind: .formula, name: "gh")
        let running = BrewOperationID(kind: .formula, name: "ripgrep")
        await harness.emit(id: done, phase: .running(.installFormula))
        await harness.emit(id: done, phase: .idle)
        await harness.emit(id: running, phase: .running(.installFormula))

        let presentation = harness.viewModel.statusPresentation

        #expect(presentation.dotState == .running)
        if case let .running(command, _) = presentation.summary {
            #expect(command == "brew install ripgrep")
        } else {
            Issue.record("expected running summary")
        }
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
