//
//  BrewDoctorRepositoryTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewDoctorRepositoryTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    private static func repository(
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32,
    ) -> BrewDoctorRepository {
        let runner = MockBrewCommandRunner(responses: [
            ["doctor"]: CommandOutput(standardOutput: stdout, standardError: stderr, terminationStatus: exitCode),
        ])
        return BrewDoctorRepository(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: brewURL))
    }

    @Test func `healthy system reports no issues`() async throws {
        let repository = Self.repository(stdout: "Your system is ready to brew.\n", exitCode: 0)
        let report = try await repository.runDiagnostics()
        #expect(report.isHealthy)
    }

    @Test func `warnings on stderr with nonzero exit are parsed, not thrown`() async throws {
        let stderr = """
        Warning: You have unlinked kegs in your Cellar.
        Run `brew link` on these:
          openssl@3
        """
        let repository = Self.repository(stderr: stderr, exitCode: 1)
        let report = try await repository.runDiagnostics()

        #expect(report.issues.count == 1)
        #expect(report.issues.first?.suggestedFix?.arguments == ["link", "openssl@3"])
    }

    @Test func `missing brew executable throws`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let repository = BrewDoctorRepository(commandRunner: runner, locator: MissingBrewExecutableLocator())

        await #expect(throws: BrewLookupError.self) {
            try await repository.runDiagnostics()
        }
    }
}
