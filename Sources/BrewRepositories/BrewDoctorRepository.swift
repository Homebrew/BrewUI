//
//  BrewDoctorRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation

/// Runs `brew doctor` read-only and parses its output into a ``DoctorReport``.
///
/// `brew doctor` exits non-zero when it finds warnings — that is the normal "issues found" path, not a
/// failure, so the exit code is ignored and both streams are parsed. A thrown error means `brew` could not
/// be located or the subprocess failed to launch. Warnings are written to stderr; the healthy message goes
/// to stdout, so both are fed to the parser.
public struct BrewDoctorRepository: DoctorRepository {
    private let commandRunner: BrewCommandRunning
    private let locator: any BrewExecutableLocating

    public init(commandRunner: BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Production wiring: real subprocess + default `brew` lookup.
    public static func live() -> BrewDoctorRepository {
        BrewDoctorRepository(commandRunner: BrewCommandService(), locator: BrewExecutableLocator())
    }

    public func runDiagnostics() async throws -> DoctorReport {
        let brew = try locator.findBrewExecutable()
        let output = try await commandRunner.run(executableURL: brew, arguments: ["doctor"])
        return DoctorOutputParser.parse(combinedOutput(of: output))
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
