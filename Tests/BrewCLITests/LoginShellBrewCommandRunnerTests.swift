//
//  LoginShellBrewCommandRunnerTests.swift
//  BrewCLITests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct LoginShellBrewCommandRunnerTests {
    // MARK: - Quoting

    @Test func `singleQuoted wraps simple tokens`() {
        #expect(LoginShellBrewCommandRunner.singleQuoted("brew") == "'brew'")
    }

    @Test func `singleQuoted preserves spaces and metacharacters inside quotes`() {
        #expect(LoginShellBrewCommandRunner.singleQuoted("package name") == "'package name'")
        #expect(LoginShellBrewCommandRunner.singleQuoted("--flag=$VAR") == "'--flag=$VAR'")
        #expect(LoginShellBrewCommandRunner.singleQuoted("a;b|c`d`") == "'a;b|c`d`'")
    }

    @Test func `singleQuoted escapes embedded single quotes posix-style`() {
        // POSIX-portable: close the quote, emit an escaped quote, reopen.
        #expect(LoginShellBrewCommandRunner.singleQuoted("it's") == "'it'\\''s'")
    }

    // MARK: - Command construction

    @Test func `shellCommand prefixes the brew path and joins arguments`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["config"],
        )
        #expect(command == "'/opt/homebrew/bin/brew' 'config'")
    }

    @Test func `shellCommand quotes each argument independently`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["info", "--installed", "--json=v2"],
        )
        #expect(command == "'/opt/homebrew/bin/brew' 'info' '--installed' '--json=v2'")
    }

    // MARK: - Wrapping behavior

    @Test func `run invokes the resolved login shell with -l -i -c`() async throws {
        let recorder = InvocationRecorder()
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(
                lookup: { URL(fileURLWithPath: "/bin/bash") },
            ),
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["doctor"],
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.executableURL.path == "/bin/bash")
        #expect(invocation.arguments.count == 4)
        #expect(invocation.arguments[0] == "-l")
        #expect(invocation.arguments[1] == "-i")
        #expect(invocation.arguments[2] == "-c")
        #expect(invocation.arguments[3] == "'/opt/homebrew/bin/brew' 'doctor'")
    }

    @Test func `run falls back to default shell when Directory Services lookup yields nil`() async throws {
        let recorder = InvocationRecorder()
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(lookup: { nil }),
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["config"],
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.executableURL.path == LoginShellResolver.defaultFallback.path)
    }

    @Test func `run returns the underlying CommandOutput verbatim`() async throws {
        let expected = CommandOutput(
            standardOutput: "ok",
            standardError: "warn",
            terminationStatus: 0,
        )
        let recorder = InvocationRecorder(stubbedOutput: expected)
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(lookup: { URL(fileURLWithPath: "/bin/zsh") }),
        )

        let output = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["config"],
        )

        #expect(output.standardOutput == "ok")
        #expect(output.standardError == "warn")
        #expect(output.terminationStatus == 0)
    }
}

private struct RecordedInvocation {
    let executableURL: URL
    let arguments: [String]
}

private actor InvocationRecorder: BrewCommandRunning {
    private(set) var invocations: [RecordedInvocation] = []
    private let stubbedOutput: CommandOutput

    init(stubbedOutput: CommandOutput = CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)) {
        self.stubbedOutput = stubbedOutput
    }

    var first: RecordedInvocation? {
        invocations.first
    }

    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        invocations.append(RecordedInvocation(executableURL: executableURL, arguments: arguments))
        return stubbedOutput
    }
}
