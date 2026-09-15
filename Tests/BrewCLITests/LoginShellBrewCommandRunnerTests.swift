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
            marker: "MARK",
            output: .pipes(forceColor: false),
        )
        #expect(command.hasSuffix("exec \"$0\" \"$@\""))
    }

    @Test func `shellCommand for fish uses argv`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            for: URL(fileURLWithPath: "/opt/homebrew/bin/fish"),
            marker: "MARK",
            output: .pipes(forceColor: false),
        )
        #expect(command.hasSuffix("exec $argv"))
    }

    @Test func `shellCommand announces the marker on both streams for pipes`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            for: URL(fileURLWithPath: "/bin/zsh"),
            marker: "MARK",
            output: .pipes(forceColor: false),
        )
        #expect(command == "printf '%s\\n' 'MARK' 1>&2; printf '%s\\n' 'MARK'; exec \"$0\" \"$@\"")
    }

    @Test func `shellCommand announces the marker once for a pseudo-terminal`() {
        let command = LoginShellBrewCommandRunner.shellCommand(
            for: URL(fileURLWithPath: "/bin/zsh"),
            marker: "MARK",
            output: .pseudoTerminal,
        )
        #expect(command == "printf '%s\\n' 'MARK'; exec \"$0\" \"$@\"")
    }

    @Test func `removingStartupNoise cuts everything through the marker's line`() {
        let text = "hello from zshrc\nMARK\n{\"foo\":1}\n"
        #expect(LoginShellBrewCommandRunner.removingStartupNoise(from: text, upTo: "MARK") == "{\"foo\":1}\n")
    }

    @Test func `removingStartupNoise leaves text unchanged when the marker is absent`() {
        let text = "{\"foo\":1}\n"
        #expect(LoginShellBrewCommandRunner.removingStartupNoise(from: text, upTo: "MARK") == text)
    }

    @Test func `removingStartupNoise returns empty when the marker is the last line`() {
        let text = "startup noise\nMARK\n"
        #expect(LoginShellBrewCommandRunner.removingStartupNoise(from: text, upTo: "MARK") == "")
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
            makeMarker: { "MARK" },
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
        #expect(invocation.arguments[3] == "printf '%s\\n' 'MARK' 1>&2; printf '%s\\n' 'MARK'; exec \"$0\" \"$@\"")
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
            makeMarker: { "MARK" },
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["config", "--foo=it's"],
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.executableURL.path == "/opt/homebrew/bin/fish")
        #expect(invocation.arguments[3] == "printf '%s\\n' 'MARK' 1>&2; printf '%s\\n' 'MARK'; exec $argv")
        #expect(invocation.arguments[4] == "/opt/homebrew/bin/brew")
        #expect(invocation.arguments[5] == "config")
        #expect(invocation.arguments[6] == "--foo=it's")
    }

    /// The exec script is POSIX (or fish); any other login shell is swapped for the default fallback.
    @Test func `run falls back to default shell when login shell is not POSIX compatible`() async throws {
        let recorder = InvocationRecorder()
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(
                lookup: { URL(fileURLWithPath: "/opt/homebrew/bin/nu") },
            ),
            makeMarker: { "MARK" },
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["config"],
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.executableURL.path == LoginShellResolver.defaultFallback.path)
        #expect(invocation.arguments == [
            "-l", "-i", "-c",
            "printf '%s\\n' 'MARK' 1>&2; printf '%s\\n' 'MARK'; exec \"$0\" \"$@\"",
            "/opt/homebrew/bin/brew", "config",
        ])
    }

    @Test func `supportedShell keeps POSIX shells and fish, replaces everything else`() {
        for name in ["sh", "bash", "zsh", "fish"] {
            let shell = URL(fileURLWithPath: "/opt/homebrew/bin/\(name)")
            #expect(LoginShellBrewCommandRunner.supportedShell(for: shell) == shell)
        }
        for name in ["nu", "xonsh", "pwsh"] {
            let shell = URL(fileURLWithPath: "/opt/homebrew/bin/\(name)")
            #expect(LoginShellBrewCommandRunner.supportedShell(for: shell) == LoginShellResolver.defaultFallback)
        }
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

    /// The shell exports what it inherits, so a variable pinned on it reaches brew.
    @Test func `run forwards the pinned environment to the shell`() async throws {
        let recorder = InvocationRecorder()
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(lookup: { URL(fileURLWithPath: "/bin/zsh") }),
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["upgrade"],
            options: BrewRunOptions(environment: ["HOMEBREW_NO_COLOR": "1"]),
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.options.environment["HOMEBREW_NO_COLOR"] == "1")
    }

    /// Reproduces the iTerm2 shell-integration report: startup noise lands on both streams ahead of
    /// the real command's output, and only the marker line tells us where it ends.
    @Test func `run strips shell startup noise from both streams`() async throws {
        let recorder = InvocationRecorder(
            stubbedOutput: CommandOutput(
                standardOutput: "hello from zshrc\nMARK\n{\"foo\":1}\n",
                standardError: "OSC 1337 junk\nMARK\nreal warning\n",
                terminationStatus: 0,
            ),
        )
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(lookup: { URL(fileURLWithPath: "/bin/zsh") }),
            makeMarker: { "MARK" },
        )

        let output = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["info", "--installed", "--json=v2"],
        )

        #expect(output.standardOutput == "{\"foo\":1}\n")
        #expect(output.standardError == "real warning\n")
    }

    @Test func `run filters the startup marker out of streamed lines`() async throws {
        let collector = LineCollector()
        let recorder = InvocationRecorder(
            linesToEmit: [
                BrewCommandOutputLine(stream: .stdout, text: "hello from zshrc"),
                BrewCommandOutputLine(stream: .stdout, text: "MARK"),
                BrewCommandOutputLine(stream: .stdout, text: "==> Installing wget"),
            ],
        )
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(lookup: { URL(fileURLWithPath: "/bin/zsh") }),
            makeMarker: { "MARK" },
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["install", "wget"],
            options: BrewRunOptions(lineObserver: { collector.append($0.text) }, output: .pseudoTerminal),
        )

        #expect(collector.all == ["==> Installing wget"])
    }

    @Test func `run filters startup markers independently from stdout and stderr`() async throws {
        let collector = LineCollector()
        let recorder = InvocationRecorder(
            linesToEmit: [
                BrewCommandOutputLine(stream: .stderr, text: "stderr startup"),
                BrewCommandOutputLine(stream: .stdout, text: "stdout startup"),
                BrewCommandOutputLine(stream: .stderr, text: "MARK"),
                BrewCommandOutputLine(stream: .stdout, text: "MARK"),
                BrewCommandOutputLine(stream: .stdout, text: "Your system is ready to brew."),
                BrewCommandOutputLine(stream: .stderr, text: "real warning"),
            ],
        )
        let wrapped = LoginShellBrewCommandRunner(
            underlying: recorder,
            shellResolver: LoginShellResolver(lookup: { URL(fileURLWithPath: "/bin/zsh") }),
            makeMarker: { "MARK" },
        )

        _ = try await wrapped.run(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            arguments: ["doctor"],
            options: BrewRunOptions(lineObserver: { collector.append($0.text) }, output: .pipes(forceColor: true)),
        )

        #expect(collector.all == ["Your system is ready to brew.", "real warning"])
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
    let options: BrewRunOptions
}

// swiftlint:disable:next unchecked_sendable
private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }
}

private actor InvocationRecorder: BrewCommandRunning {
    private(set) var invocations: [RecordedInvocation] = []
    private let stubbedOutput: CommandOutput
    private let linesToEmit: [BrewCommandOutputLine]

    init(
        stubbedOutput: CommandOutput = CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0),
        linesToEmit: [BrewCommandOutputLine] = [],
    ) {
        self.stubbedOutput = stubbedOutput
        self.linesToEmit = linesToEmit
    }

    var first: RecordedInvocation? {
        invocations.first
    }

    func run(executableURL: URL, arguments: [String], options: BrewRunOptions) async throws -> CommandOutput {
        invocations.append(RecordedInvocation(executableURL: executableURL, arguments: arguments, options: options))
        linesToEmit.forEach { options.lineObserver?($0) }
        return stubbedOutput
    }
}
