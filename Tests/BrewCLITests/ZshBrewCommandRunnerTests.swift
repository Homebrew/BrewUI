//
//  ZshBrewCommandRunnerTests.swift
//  BrewCLITests
//

@testable import BrewCLI
import BrewCore
import Darwin
import Foundation
import Synchronization
import Testing

struct ZshBrewCommandRunnerTests {
    @Test(arguments: [0, 1, 2])
    func `askpass path survives clean environments and output modes`(mode: Int) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("askpass ' $; \(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let helper = directory.appendingPathComponent("helper")
        try FileManager.default.createSymbolicLink(at: helper, withDestinationURL: URL(fileURLWithPath: "/usr/bin/printf"))
        let output = try await ZshBrewCommandRunner(
            underlying: PollutedEnvironmentRunner(
                startupScript: "export SUDO_ASKPASS=/unexpected; ",
                service: mode == 2 ? BrewCommandService(makeTerminal: { throw CocoaError(.fileWriteUnknown) }) : BrewCommandService(),
            ),
            askpassExecutableURL: helper,
        ).run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s' \"$SUDO_ASKPASS\""],
            options: BrewRunOptions(output: mode == 0 ? .pipes(forceColor: false) : .pseudoTerminal),
        )
        #expect(output.standardOutput == helper.path)
    }

    @Test func `explicit askpass overrides the bundled default and missing helpers are omitted`() async throws {
        let executable = URL(fileURLWithPath: "/usr/bin/env")
        let overridden = try await ZshBrewCommandRunner(askpassExecutableURL: executable).run(
            executableURL: executable, arguments: [],
            options: BrewRunOptions(environment: ["SUDO_ASKPASS": "/custom/helper"]),
        )
        #expect(overridden.standardOutput.contains("SUDO_ASKPASS=/custom/helper\n"))
        let missing = try await ZshBrewCommandRunner(askpassExecutableURL: URL(fileURLWithPath: "/nonexistent/askpass")).run(
            executableURL: executable, arguments: [],
        )
        #expect(!missing.standardOutput.contains("SUDO_ASKPASS"))
    }

    @Test(arguments: [false, true])
    func `fake brew consumes askpass privately and preserves rejection diagnostics`(reject: Bool) async throws {
        let helper = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: helper) }
        try (reject ? "#!/bin/sh\nexit 1\n" : "#!/bin/sh\nprintf 'dummy-response\\n'\n").write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        let lines = Mutex<[String]>([])
        let output = try await ZshBrewCommandRunner(askpassExecutableURL: helper).run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", """
            response=$("$SUDO_ASKPASS" 'synthetic prompt') || { printf 'authentication rejected\\n' >&2; exit 12; }
            test "$response" = dummy-response && printf 'success\\n'
            """],
            options: BrewRunOptions(lineObserver: { line in lines.withLock { $0.append(line.text) } }),
        )
        #expect(output == CommandOutput(
            standardOutput: reject ? "" : "success\n",
            standardError: reject ? "authentication rejected\n" : "",
            terminationStatus: reject ? 12 : 0,
        ))
        #expect(lines.withLock { $0 } == [reject ? "authentication rejected" : "success"])
    }

    @Test(arguments: [BrewRunOptions.OutputChannel.pipes(forceColor: false), .pseudoTerminal])
    func `cancellation stops a waiting askpass and its caller`(channel: BrewRunOptions.OutputChannel) async throws {
        let helper = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: helper) }
        try "#!/bin/sh\nprintf '%s\\n' $$ >&2\nexec /bin/sleep 30\n".write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        let processes = Mutex<[Int32]>([])
        let runner = ZshBrewCommandRunner(askpassExecutableURL: helper)
        let task = Task {
            try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "printf '%s\\n' $$; response=$(\"$SUDO_ASKPASS\" 'synthetic prompt')"],
                options: BrewRunOptions(lineObserver: { line in
                    if line.isComplete, let pid = Int32(line.text) {
                        processes.withLock { $0.append(pid) }
                    }
                }, output: channel),
            )
        }
        defer { task.cancel() }
        try await waitUntil("askpass did not become ready", timeout: .seconds(30)) { processes.withLock { $0.count == 2 } }
        try #require(processes.withLock { $0.count == 2 })
        task.cancel()
        _ = await task.result
        try await waitUntil("askpass or its caller survived cancellation") {
            processes.withLock { $0.allSatisfy { kill($0, 0) == -1 && errno == ESRCH } }
        }
        let next = try await runner.run(executableURL: URL(fileURLWithPath: "/usr/bin/printf"), arguments: ["next"])
        #expect(next.standardOutput == "next")
    }

    /// Runs real sudo the way Homebrew's `SystemCommand#sudo_prefix` does once `SUDO_ASKPASS` is set.
    /// The displayed path's pseudo-terminal is not a controlling terminal, so sudo cannot prompt on it.
    /// The helper refuses, so nothing is authenticated or run as root.
    @Test(.enabled(if: sudoRequiresPassword()), .timeLimit(.minutes(1)), arguments: [
        BrewRunOptions.OutputChannel.pipes(forceColor: false), .pseudoTerminal,
    ])
    func `real sudo consults askpass instead of a terminal`(channel: BrewRunOptions.OutputChannel) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let helper = directory.appendingPathComponent("helper")
        try "#!/bin/sh\n: > \"${0%/*}/consulted\"\nexit 1\n".write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)

        let output = try await ZshBrewCommandRunner(askpassExecutableURL: helper).run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "(: < /dev/tty) 2> /dev/null && echo controlling-terminal; exec /usr/bin/sudo -k -A /usr/bin/true"],
            options: BrewRunOptions(output: channel),
        )

        #expect(!output.standardOutput.contains("controlling-terminal"))
        #expect(output.terminationStatus != 0)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("consulted").path))
    }

    @Test func `brew receives only the explicit environment`() async throws {
        let output = try await ZshBrewCommandRunner(underlying: PollutedEnvironmentRunner()).run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [],
        )

        let keys = output.standardOutput.split(separator: "\n").compactMap { $0.split(separator: "=", maxSplits: 1).first }
        #expect(Set(keys) == ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "SHELL", "PATH"])
    }

    @Test func `the executable path and arguments survive shell metacharacters`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("brew ' $; \(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("brew")
        try FileManager.default.createSymbolicLink(at: executable, withDestinationURL: URL(fileURLWithPath: "/usr/bin/printf"))
        let arguments = ["", "two words", "it's", "$(echo injected)", "a;b", "*", "a\nb"]

        let output = try await ZshBrewCommandRunner().run(
            executableURL: executable,
            arguments: ["<%s>"] + arguments,
        )

        #expect(output.standardOutput == arguments.map { "<\($0)>" }.joined())
    }

    @Test func `user startup files are skipped`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in [".zshenv", ".zprofile", ".zshrc", ".zlogin"] {
            try "print sourced > \"$ZDOTDIR/sourced\"\n".write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        _ = try await ZshBrewCommandRunner().run(
            executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["brew output"],
            options: BrewRunOptions(environment: ["HOME": directory.path, "ZDOTDIR": directory.path]),
        )

        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("sourced").path))
    }

    @Test func `exports from system startup are cleared before Homebrew`() async throws {
        let output = try await ZshBrewCommandRunner(
            underlying: PollutedEnvironmentRunner(startupScript: "export HOMEBREW_STARTUP_LEAK=yes PATH=/unexpected; "),
        ).run(executableURL: URL(fileURLWithPath: "/usr/bin/env"), arguments: [])

        #expect(!output.standardOutput.contains("/unexpected") && !output.standardOutput.contains("HOMEBREW_STARTUP_LEAK"))
    }

    @Test(arguments: [BrewRunOptions.OutputChannel.pipes(forceColor: true), .pseudoTerminal])
    func `colour controls reach Homebrew`(channel: BrewRunOptions.OutputChannel) async throws {
        let output = try await ZshBrewCommandRunner().run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s|%s' \"$HOMEBREW_COLOR\" \"$CLICOLOR_FORCE\""],
            options: BrewRunOptions(output: channel),
        )

        #expect(output.standardOutput == "1|1")
    }

    @Test func `explicit output controls survive a terminal allocation failure`() async throws {
        let lines = Mutex<[String]>([])
        let output = try await ZshBrewCommandRunner(
            underlying: PollutedEnvironmentRunner(
                startupScript: "printf 'startup banner'; printf 'startup warning' >&2; ",
                service: BrewCommandService(makeTerminal: { throw CocoaError(.fileWriteUnknown) }),
            ),
        ).run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s|%s' \"$HOMEBREW_COLOR\" \"$HOMEBREW_NO_COLOR\""],
            options: BrewRunOptions(
                lineObserver: { line in lines.withLock { $0.append(line.text) } },
                output: .pseudoTerminal,
                environment: ["HOMEBREW_NO_COLOR": "1"],
            ),
        )

        #expect(output.standardOutput == "1|1")
        #expect(output.standardError.isEmpty)
        #expect(lines.withLock { $0 } == ["1|1"])
    }

    @Test func `PATH and SHELL cannot be overridden`() async throws {
        let output = try await ZshBrewCommandRunner().run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s|%s' \"$PATH\" \"$SHELL\""],
            options: BrewRunOptions(environment: ["PATH": "/unexpected", "SHELL": "/bin/bash"]),
        )

        #expect(output.standardOutput == "/bin:/sbin:/usr/bin:/bin|/bin/zsh")
    }

    @Test func `executables in Homebrew sbin can be run by name`() async throws {
        let prefix = FileManager.default.temporaryDirectory.appendingPathComponent("brew prefix \(UUID())")
        defer { try? FileManager.default.removeItem(at: prefix) }
        for directory in ["bin", "sbin"] {
            try FileManager.default.createDirectory(at: prefix.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        let executable = prefix.appendingPathComponent("bin/brew")
        try FileManager.default.createSymbolicLink(at: executable, withDestinationURL: URL(fileURLWithPath: "/bin/sh"))
        try FileManager.default.createSymbolicLink(
            at: prefix.appendingPathComponent("sbin/sbin-probe"),
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/printf"),
        )

        let output = try await ZshBrewCommandRunner().run(
            executableURL: executable,
            arguments: ["-c", "sbin-probe 'found sbin'"],
        )

        #expect(output == CommandOutput(standardOutput: "found sbin", standardError: "", terminationStatus: 0))
    }

    @Test func `buffered output and failure status are preserved`() async throws {
        let output = try await ZshBrewCommandRunner().run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf 'output'; printf 'warning' >&2; exit 12"],
        )

        #expect(output == CommandOutput(standardOutput: "output", standardError: "warning", terminationStatus: 12))
    }

    @Test func `streaming preserves the first output on both streams`() async throws {
        let lines = Mutex<[String]>([])
        _ = try await ZshBrewCommandRunner().run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf 'output\\n'; printf 'warning\\n' >&2"],
            options: BrewRunOptions(lineObserver: { line in lines.withLock { $0.append(line.text) } }),
        )

        #expect(lines.withLock { $0.sorted() } == ["output", "warning"])
    }

    @Test(arguments: [BrewRunOptions.OutputChannel.pipes(forceColor: false), .pseudoTerminal])
    func `system startup banners are removed from buffered and streamed output`(channel: BrewRunOptions.OutputChannel) async throws {
        let lines = Mutex<[BrewCommandOutputLine]>([])
        let output = try await ZshBrewCommandRunner(
            underlying: PollutedEnvironmentRunner(
                startupScript: "printf 'startup\\nbanner'; printf 'startup\\nwarning' >&2; sleep 0.05; ",
            ),
        ).run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '{\"formulae\":[]}\\n'; printf 'brew warning\\n' >&2; exit 12"],
            options: BrewRunOptions(lineObserver: { line in lines.withLock { $0.append(line) } }, output: channel),
        )

        #expect(output.standardOutput == (channel == .pseudoTerminal ? "{\"formulae\":[]}\nbrew warning\n" : "{\"formulae\":[]}\n"))
        #expect(output.standardError == (channel == .pseudoTerminal ? "" : "brew warning\n"))
        #expect(output.terminationStatus == 12)
        #expect(lines.withLock { $0.filter(\.isComplete).map(\.text).sorted() } == ["brew warning", "{\"formulae\":[]}"])
        #expect(lines.withLock { $0.allSatisfy { "{\"formulae\":[]}".hasPrefix($0.text) || "brew warning".hasPrefix($0.text) } })
    }

    @Test(arguments: [BrewRunOptions.OutputChannel.pipes(forceColor: false), .pseudoTerminal])
    func `startup failures retain their diagnostics`(channel: BrewRunOptions.OutputChannel) async throws {
        let lines = Mutex<[BrewCommandOutputLine]>([])
        let output = try await ZshBrewCommandRunner(
            underlying: PollutedEnvironmentRunner(startupScript: "printf 'startup failed\\n' >&2; exit 17; "),
        ).run(
            executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["unreachable"],
            options: BrewRunOptions(lineObserver: { line in lines.withLock { $0.append(line) } }, output: channel),
        )

        #expect(output.standardOutput == (channel == .pseudoTerminal ? "startup failed\n" : ""))
        #expect(output.standardError == (channel == .pseudoTerminal ? "" : "startup failed\n"))
        #expect(output.terminationStatus == 17)
        #expect(lines.withLock { $0.filter(\.isComplete).map(\.text) } == ["startup failed"])
    }
}

private struct PollutedEnvironmentRunner: BrewCommandRunning {
    var environment = [
        "HOMEBREW_NO_INSTALL_FROM_API": "1",
        "HOMEBREW_NO_ENV_FILE": "1",
        "HOMEBREW_CASK_OPTS": "--no-quarantine",
        "PATH": "/bin:/usr/bin:/unexpected",
        "SHELL": "/nonexistent/shell",
        "XDG_CONFIG_HOME": "/unexpected/config",
        "BASH_ENV": "/unexpected/bashenv",
        "SUDO_ASKPASS": "/unexpected/askpass",
    ]
    var startupScript = ""
    var service = BrewCommandService()

    func run(executableURL: URL, arguments: [String], options: BrewRunOptions) async throws -> CommandOutput {
        var arguments = arguments
        // Simulate /etc/zshenv without modifying the machine's startup files.
        if let index = arguments.firstIndex(of: "-c") {
            arguments[index + 1] = startupScript + arguments[index + 1]
        }
        var options = options
        options.environment.merge(environment) { _, polluted in polluted }
        return try await service.run(executableURL: executableURL, arguments: arguments, options: options)
    }
}

/// Passwordless sudo, as on CI runners, never consults askpass. `-k` ignores cached credentials.
private func sudoRequiresPassword() -> Bool {
    let sudo = Process()
    sudo.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    sudo.arguments = ["-k", "-n", "/usr/bin/true"]
    sudo.standardInput = FileHandle.nullDevice
    sudo.standardOutput = FileHandle.nullDevice
    sudo.standardError = FileHandle.nullDevice
    do {
        try sudo.run()
    } catch {
        return false
    }
    sudo.waitUntilExit()
    return sudo.terminationStatus != 0
}
