//
//  DoctorReadCommandTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct DoctorReadCommandTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    @Test func `captures stdout when stderr is empty`() async throws {
        let command = DoctorReadCommand()
        let runner = StubbedCommandRunner(
            output: CommandOutput(
                standardOutput: "Your system is ready to brew.\n",
                standardError: "",
                terminationStatus: 0,
            ),
        )
        try await command.run(in: Self.context(runner: runner))

        #expect(await command.capturedOutput == "Your system is ready to brew.\n")
    }

    @Test func `captures stderr when stdout is empty`() async throws {
        let command = DoctorReadCommand()
        let runner = StubbedCommandRunner(
            output: CommandOutput(standardOutput: "", standardError: "Warning: unlinked kegs\n", terminationStatus: 1),
        )
        try await command.run(in: Self.context(runner: runner))

        #expect(await command.capturedOutput == "Warning: unlinked kegs\n")
    }

    @Test func `joins stdout and stderr with a newline when both are populated`() async throws {
        let command = DoctorReadCommand()
        let runner = StubbedCommandRunner(
            output: CommandOutput(standardOutput: "ok line", standardError: "Warning: detail", terminationStatus: 1),
        )
        try await command.run(in: Self.context(runner: runner))

        #expect(await command.capturedOutput == "ok line\nWarning: detail")
    }

    @Test func `strips ANSI colour codes from captured output`() async throws {
        // Console streaming forces HOMEBREW_COLOR, so brew doctor colourises its warning prefix/headers.
        // The captured copy feeds the colour-blind parser, so it must come back plain.
        let command = DoctorReadCommand()
        let runner = StubbedCommandRunner(
            output: CommandOutput(
                standardOutput: "\u{1B}[1;34m==>\u{1B}[0m Checking",
                standardError: "\u{1B}[31mWarning:\u{1B}[0m unlinked kegs",
                terminationStatus: 1,
            ),
        )
        try await command.run(in: Self.context(runner: runner))

        #expect(await command.capturedOutput == "==> Checking\nWarning: unlinked kegs")
    }

    @Test func `returns empty when both streams are empty`() async throws {
        let command = DoctorReadCommand()
        let runner = StubbedCommandRunner(
            output: CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0),
        )
        try await command.run(in: Self.context(runner: runner))

        #expect(await command.capturedOutput == "")
    }

    private static func context(runner: any BrewCommandRunning) -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
    }
}

private actor StubbedCommandRunner: BrewCommandRunning {
    private let output: CommandOutput

    init(output: CommandOutput) {
        self.output = output
    }

    func run(executableURL _: URL, arguments _: [String]) async throws -> CommandOutput {
        output
    }
}
