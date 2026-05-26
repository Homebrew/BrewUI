//
//  ConsoleStatusPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct ConsoleStatusPresentationTests {
    @Test func `empty registry presents idle`() {
        let registry = JobRegistry()

        let presentation = ConsoleStatusPresentation.from(registry: registry)

        #expect(presentation.dotState == .idle)
        #expect(presentation.summary == .idle)
        #expect(!presentation.isRunning)
    }

    @Test func `active job presents running with the job command and short label`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")
        registry.handlePhase(id: id, phase: .running(.installFormula))

        let presentation = ConsoleStatusPresentation.from(registry: registry)

        #expect(presentation.dotState == .running)
        #expect(presentation.summary == .running(command: "brew install gh", shortLabel: "running"))
        #expect(presentation.isRunning)
    }

    @Test func `succeeded terminal job presents green dot and done summary`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")
        registry.handlePhase(id: id, phase: .running(.installFormula))
        registry.handlePhase(id: id, phase: .idle)

        let presentation = ConsoleStatusPresentation.from(registry: registry)

        #expect(presentation.dotState == .succeeded)
        #expect(presentation.summary == .completed(command: "brew install gh", succeeded: true, exitCode: 0))
        #expect(!presentation.isRunning)
    }

    @Test func `failed terminal job presents red dot and exit code summary`() {
        let registry = JobRegistry()
        let id = BrewOperationID(rawValue: "formula:gh")
        registry.handlePhase(id: id, phase: .running(.installFormula))
        registry.handlePhase(id: id, phase: .failed(reason: .brewCommand(exitCode: 9, stderr: "nope")))

        let presentation = ConsoleStatusPresentation.from(registry: registry)

        #expect(presentation.dotState == .failed)
        #expect(presentation.summary == .completed(command: "brew install gh", succeeded: false, exitCode: 9))
        #expect(!presentation.isRunning)
    }

    @Test func `active job is preferred over recent completed`() {
        let registry = JobRegistry()
        let done = BrewOperationID(rawValue: "formula:gh")
        let running = BrewOperationID(rawValue: "formula:ripgrep")
        registry.handlePhase(id: done, phase: .running(.installFormula))
        registry.handlePhase(id: done, phase: .idle)
        registry.handlePhase(id: running, phase: .running(.installFormula))

        let presentation = ConsoleStatusPresentation.from(registry: registry)

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
