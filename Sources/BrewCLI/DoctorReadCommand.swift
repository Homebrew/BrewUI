//
//  DoctorReadCommand.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Runs `brew doctor` through ``BrewCommandCenter`` so the bottom console picks it up as a pill and
/// streams output the same way mutating ops do. Read-only despite living under ``BrewMutatingCommand`` —
/// see the docs on ``BrewOperationKind/doctorRead`` for the framing note.
///
/// Stores the combined stdout+stderr text the underlying ``BrewCommandRunning`` returns so the
/// repository can parse it after submit completes (the protocol's ``BrewMutatingCommand/run(in:)``
/// returns `Void`, so the actor's `capturedOutput` is the hand-off channel). Use one instance per submit
/// — the actor isolation ensures the repository reads the captured text only after `run(in:)` has finished.
public actor DoctorReadCommand: BrewMutatingCommand {
    public nonisolated let operationKind: BrewOperationKind = .doctorRead
    public private(set) var capturedOutput: String = ""

    public init() {}

    public func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
        let output = try await context.commandRunner.run(executableURL: brew, arguments: ["doctor"])
        // `brew doctor` exits non-zero when it finds warnings — normal, not an error. Capture both
        // streams and let the parser decide; the runner's task-local sink has already broadcast lines
        // to the console.
        capturedOutput = combinedOutput(of: output)
    }

    private func combinedOutput(of output: CommandOutput) -> String {
        let standardError = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !standardError.isEmpty else {
            return output.standardOutput
        }
        let standardOutput = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !standardOutput.isEmpty else {
            return output.standardError
        }
        return output.standardOutput + "\n" + output.standardError
    }
}
