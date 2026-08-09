//
//  SerialBrewCommandCenterRunOptionsTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

/// The mode → run-options mapping is the safety property behind the pty work: output that gets parsed must
/// keep stdout and stderr apart, which only the pipe path does.
struct SerialBrewCommandCenterRunOptionsTests {
    @Test func `display work runs against a pseudo-terminal`() async throws {
        let recorder = RunOptionsRecorder()
        let center = makeCenter(recorder)

        try await center.perform(
            BrewCommands.install("wget", kind: .formula),
            id: .maintenance(token: "install", displayCommand: "brew install wget"),
        )

        #expect(recorder.recorded()?.usesPseudoTerminal == true)
    }

    @Test func `capture work stays on pipes`() async throws {
        let recorder = RunOptionsRecorder()
        let center = makeCenter(recorder)

        _ = try await center.capture(
            BrewCommands.doctorRead(),
            id: .maintenance(token: "doctor", displayCommand: "brew doctor"),
        )

        #expect(recorder.recorded()?.usesPseudoTerminal == false)
    }

    @Test func `capture work still forces colour, which a pipe would otherwise strip`() async throws {
        let recorder = RunOptionsRecorder()
        let center = makeCenter(recorder)

        _ = try await center.capture(
            BrewCommands.doctorRead(),
            id: .maintenance(token: "doctor", displayCommand: "brew doctor"),
        )

        #expect(recorder.recorded()?.forceColor == true)
    }

    @Test func `display work does not force colour, because a terminal already supplies it`() async throws {
        let recorder = RunOptionsRecorder()
        let center = makeCenter(recorder)

        try await center.perform(
            BrewCommands.install("wget", kind: .formula),
            id: .maintenance(token: "install", displayCommand: "brew install wget"),
        )

        #expect(recorder.recorded()?.forceColor == false)
    }
}

private func makeCenter(_ recorder: RunOptionsRecorder) -> SerialBrewCommandCenter {
    let context = BrewCommandExecutionContext(
        commandRunner: RecordingRunner(recorder: recorder),
        locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
    )
    return SerialBrewCommandCenter(executionContext: context)
}

/// Captures the ``BrewRunOptions`` the center hands down, without spawning anything.
private struct RecordingRunner: BrewCommandRunning {
    let recorder: RunOptionsRecorder

    func run(executableURL _: URL, arguments _: [String], options: BrewRunOptions) async throws -> CommandOutput {
        recorder.record(options)
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }
}

// swiftlint:disable:next unchecked_sendable
private final class RunOptionsRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var options: BrewRunOptions?

    func record(_ newOptions: BrewRunOptions) {
        lock.lock()
        defer { lock.unlock() }
        options = newOptions
    }

    func recorded() -> BrewRunOptions? {
        lock.lock()
        defer { lock.unlock() }
        return options
    }
}
