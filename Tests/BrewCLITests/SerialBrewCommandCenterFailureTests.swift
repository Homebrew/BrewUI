//
//  SerialBrewCommandCenterFailureTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

/// Display work runs on a terminal, which merges the streams and leaves `standardError` empty. These pin
/// the consequence: what the user is told when an install fails has to come from the merged transcript.
struct SerialBrewCommandCenterFailureTests {
    @Test func `a failed display run reports brew's own message`() async throws {
        let center = makeCenter(
            FixedOutputRunner(standardOutput: "==> Downloading\nError: wget is not installed\n", exitCode: 1),
        )

        await #expect(throws: BrewCommandError.self) {
            try await center.perform(
                BrewCommands.install("wget", kind: .formula),
                id: .maintenance(token: "install", displayCommand: "brew install wget"),
            )
        }
        #expect(await failureMessage(from: center).contains("Error: wget is not installed"))
    }

    @Test func `the reported failure is not the generic fallback`() async {
        let center = makeCenter(FixedOutputRunner(standardOutput: "Error: disk full\n", exitCode: 1))

        try? await center.perform(
            BrewCommands.install("wget", kind: .formula),
            id: .maintenance(token: "install", displayCommand: "brew install wget"),
        )

        // `OperationFailure` falls back to a generic string only when it is handed nothing to say.
        #expect(await failureMessage(from: center) == "Error: disk full")
    }

    @Test func `a successful display run reports no failure`() async throws {
        let center = makeCenter(FixedOutputRunner(standardOutput: "==> Poured\n", exitCode: 0))

        try await center.perform(
            BrewCommands.install("wget", kind: .formula),
            id: .maintenance(token: "install", displayCommand: "brew install wget"),
        )

        if case .failed = await center.phase(for: .maintenance(token: "install", displayCommand: "brew install wget")) {
            Issue.record("a zero exit should not be reported as a failure")
        }
    }
}

private func failureMessage(from center: SerialBrewCommandCenter) async -> String {
    let phase = await center.phase(for: .maintenance(token: "install", displayCommand: "brew install wget"))
    guard case let .failed(reason) = phase else {
        return ""
    }
    return reason.userFacingMessage
}

private func makeCenter(_ runner: FixedOutputRunner) -> SerialBrewCommandCenter {
    SerialBrewCommandCenter(
        executionContext: BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
        ),
    )
}

/// Stands in for a terminal-backed run: everything on stdout, nothing on stderr.
private struct FixedOutputRunner: BrewCommandRunning {
    let standardOutput: String
    let exitCode: Int32

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        CommandOutput(standardOutput: standardOutput, standardError: "", terminationStatus: exitCode)
    }
}
