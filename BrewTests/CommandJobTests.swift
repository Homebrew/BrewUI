//
//  CommandJobTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct CommandJobTests {
    @Test func `materialize for formula install synthesizes brew install command`() {
        let id = BrewOperationID(rawValue: "formula:gh")
        let job = CommandJob.materialize(
            id: id,
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        #expect(job.command == "brew install gh")
        #expect(job.scope == .package(name: "gh"))
    }

    @Test func `materialize for cask install includes --cask flag`() {
        let id = BrewOperationID(rawValue: "cask:firefox")
        let job = CommandJob.materialize(
            id: id,
            kind: .installCask,
            phase: .running(.installCask),
        )

        #expect(job.command == "brew install --cask firefox")
        #expect(job.scope == .package(name: "firefox"))
    }

    @Test func `materialize for cask uninstall includes --cask flag`() {
        let id = BrewOperationID(rawValue: "cask:firefox")
        let job = CommandJob.materialize(
            id: id,
            kind: .uninstallCask,
            phase: .running(.uninstallCask),
        )

        #expect(job.command == "brew uninstall --cask firefox")
    }

    @Test func `materialize for formula upgrade synthesizes brew upgrade command`() {
        let id = BrewOperationID(rawValue: "formula:gh")
        let job = CommandJob.materialize(
            id: id,
            kind: .upgradeFormula,
            phase: .running(.upgradeFormula),
        )

        #expect(job.command == "brew upgrade gh")
    }

    @Test func `materialize with unparseable id falls back to global scope and raw id`() {
        let id = BrewOperationID(rawValue: "weird-no-colon")
        let job = CommandJob.materialize(
            id: id,
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        #expect(job.command == "brew install weird-no-colon")
        #expect(job.scope == .global)
    }

    @Test func `updatePhase from running to idle sets exit code zero`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(rawValue: "formula:gh"),
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
            id: BrewOperationID(rawValue: "formula:gh"),
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
            id: BrewOperationID(rawValue: "formula:gh"),
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
            id: BrewOperationID(rawValue: "formula:gh"),
            command: "brew install gh",
            scope: .package(name: "gh"),
            startedAt: Date(),
            phase: .idle,
        )

        job.updatePhase(.idle)

        #expect(!job.isTerminal)
        #expect(job.exitCode == nil)
    }

    @Test func `appendOutput grows the buffer in order`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(rawValue: "formula:gh"),
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
}
