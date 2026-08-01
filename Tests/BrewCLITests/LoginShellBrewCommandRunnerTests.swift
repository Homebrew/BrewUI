//
//  LoginShellBrewCommandRunnerTests.swift
//  BrewCLITests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct LoginShellBrewCommandRunnerTests {
    // MARK: - Command construction

    @Test func `shellCommand for posix shells uses positional parameters`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            for: URL(fileURLWithPath: "/bin/zsh"),
        )
        #expect(command == "exec \"$0\" \"$@\"")
    }

    @Test func `shellCommand for fish uses argv`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            for: URL(fileURLWithPath: "/opt/homebrew/bin/fish"),
        )
        #expect(command == "exec $argv")
    }

    @Test func `shellArguments prefixes the brew path and appends arguments`() {
        let arguments = LoginShellBrewCommandRunner.shellArguments(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["info", "--installed", "--json=v2"],
        )
        #expect(arguments == ["/opt/homebrew/bin/brew", "info", "--installed", "--json=v2"])
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
        #expect(invocation.arguments.count == 6)
        #expect(invocation.arguments[0] == "-l")
        #expect(invocation.arguments[1] == "-i")
        #expect(invocation.arguments[2] == "-c")
        #expect(invocation.arguments[3] == "exec \"$0\" \"$@\"")
        #expect(invocation.arguments[4] == "/opt/homebrew/bin/brew")
        #expect(invocation.arguments[5] == "doctor")
    }

    @Test func `run uses fish-compatible exec script when login shell is fish`() async throws {
        let recorder = InvocationRecorder()
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(
                lookup: { URL(fileURLWithPath: "/opt/homebrew/bin/fish") },
            ),
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["config", "--foo=it's"],
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.executableURL.path == "/opt/homebrew/bin/fish")
        #expect(invocation.arguments[3] == "exec $argv")
        #expect(invocation.arguments[4] == "/opt/homebrew/bin/brew")
        #expect(invocation.arguments[5] == "config")
        #expect(invocation.arguments[6] == "--foo=it's")
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

    func run(executableURL: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        invocations.append(RecordedInvocation(executableURL: executableURL, arguments: arguments))
        return stubbedOutput
    }
}
