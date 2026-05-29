//
//  BrewCommandServiceTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewCommandServiceTests {
    @Test func `run captures stdout and stderr`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")
        let output = try await service.run(
            executableURL: executable,
            arguments: ["-lc", "printf 'hello-out'; printf 'hello-err' >&2"],
        )

        #expect(output.terminationStatus == 0)
        #expect(output.standardOutput == "hello-out")
        #expect(output.standardError == "hello-err")
    }

    @Test func `run completes with large stdout and stderr`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")
        let output = try await service.run(
            executableURL: executable,
            arguments: [
                "-lc",
                "python3 -c \"import sys; sys.stdout.write('a'*250000); sys.stderr.write('b'*250000)\"",
            ],
        )

        #expect(output.terminationStatus == 0)
        #expect(output.standardOutput.count == 250_000)
        #expect(output.standardError.count == 250_000)
    }

    @Test func `run throws CancellationError when caller task is cancelled`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")
        let task = Task {
            try await service.run(
                executableURL: executable,
                arguments: ["-lc", "sleep 30"],
            )
        }

        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
