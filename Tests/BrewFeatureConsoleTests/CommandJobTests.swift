//
//  CommandJobTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureConsole
import BrewRepositoryInterfaces
import BrewRepositories
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct CommandJobTests {
    @Test func `materialize for formula install synthesizes brew install command`() {
        let id = BrewOperationID(kind: .formula, name: "gh")
        let job = CommandJob.materialize(
            id: id,
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        #expect(job.command == "brew install gh")
    }

    @Test func `materialize for cask install includes --cask flag`() {
        let id = BrewOperationID(kind: .cask, name: "firefox")
        let job = CommandJob.materialize(
            id: id,
            kind: .installCask,
            phase: .running(.installCask),
        )

        #expect(job.command == "brew install --cask firefox")
    }

    @Test func `materialize for cask uninstall includes --cask flag`() {
        let id = BrewOperationID(kind: .cask, name: "firefox")
        let job = CommandJob.materialize(
            id: id,
            kind: .uninstallCask,
            phase: .running(.uninstallCask),
        )

        #expect(job.command == "brew uninstall --cask firefox")
    }

    @Test func `materialize for formula upgrade synthesizes brew upgrade command`() {
        let id = BrewOperationID(kind: .formula, name: "gh")
        let job = CommandJob.materialize(
            id: id,
            kind: .upgradeFormula,
            phase: .running(.upgradeFormula),
        )

        #expect(job.command == "brew upgrade gh")
    }

    @Test func `updatePhase from running to idle sets exit code zero`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        job.updatePhase(.idle)

        #expect(job.isTerminal)
        #expect(job.succeeded)
        #expect(job.exitCode == 0)
    }

    @Test func `updatePhase to brew command failure captures exit code from reason`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        job.updatePhase(.failed(reason: .brewCommand(exitCode: 17, stderr: "boom")))

        #expect(job.isTerminal)
        #expect(!job.succeeded)
        #expect(job.exitCode == 17)
    }

    @Test func `updatePhase to non-brew failure uses sentinel exit code`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        job.updatePhase(.failed(reason: .brewExecutableNotFound))

        #expect(job.isTerminal)
        #expect(!job.succeeded)
        #expect(job.exitCode == -1)
    }

    @Test func `updatePhase from idle to idle does not back-fill an exit code`() {
        let job = CommandJob(
            id: BrewOperationID(kind: .formula, name: "gh"),
            command: "brew install gh",
            startedAt: Date(),
            phase: .idle,
        )

        job.updatePhase(.idle)

        #expect(!job.isTerminal)
        #expect(job.exitCode == nil)
    }

    @Test func `appendOutput grows the buffer in order`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "first"))
        job.appendOutput(BrewCommandOutputLine(stream: .stderr, text: "warn"))

        #expect(job.output.count == 2)
        #expect(job.output[0].text == "first")
        #expect(job.output[0].stream == .stdout)
        #expect(job.output[1].stream == .stderr)
    }

    @Test func `appendOutput evicts oldest lines once the cap is exceeded`() {
        let job = CommandJob(
            id: BrewOperationID(kind: .formula, name: "gh"),
            command: "brew install gh",
            startedAt: Date(),
            phase: .running(.installFormula),
            maxOutputLines: 3,
        )

        for index in 1 ... 5 {
            job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "line\(index)"))
        }

        #expect(job.output.map(\.text) == ["line3", "line4", "line5"])
    }

    @Test func `dotState is running while not terminal`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        #expect(job.dotState == .running)
    }

    @Test func `dotState is succeeded after a zero-exit terminal transition`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        job.updatePhase(.idle)

        #expect(job.dotState == .succeeded)
    }

    @Test func `dotState is failed after a non-zero-exit terminal transition`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        job.updatePhase(.failed(reason: .brewCommand(exitCode: 1, stderr: "boom")))

        #expect(job.dotState == .failed)
    }
}
