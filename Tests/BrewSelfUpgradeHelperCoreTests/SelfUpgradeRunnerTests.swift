//
//  SelfUpgradeRunnerTests.swift
//  BrewSelfUpgradeHelperCoreTests
//

import BrewCLI
import BrewCore
@testable import BrewSelfUpgradeHelperCore
import Foundation
import Testing

/// The upgrade runs while the app is dead, so anything it gets wrong is only visible afterwards — as a user
/// whose app came back at the old version, or never came back at all.
struct SelfUpgradeRunnerTests {
    // MARK: Exit status

    @Test func `a brew that exits zero succeeded`() async throws {
        let brew = try FakeExecutable(script: "exit 0")
        defer { brew.remove() }

        let outcome = await FakeExecutable.runner().run(
            executablePath: brew.path,
            arguments: ["upgrade", "--cask", "homebrew-app"],
            environment: [:],
            timeout: 30,
        )

        #expect(outcome.succeeded)
    }

    /// Homebrew exits non-zero for a download that failed, a checksum mismatch, a cask that has gone away.
    /// Every one of them has to reach the app as a failure, or it claims to have upgraded and has not.
    @Test func `a brew that exits non-zero failed, and the code is reported`() async throws {
        let brew = try FakeExecutable(script: "exit 12")
        defer { brew.remove() }

        let outcome = await FakeExecutable.runner().run(
            executablePath: brew.path,
            arguments: ["upgrade"],
            environment: [:],
            timeout: 30,
        )

        #expect(!outcome.succeeded)
        #expect(outcome.detail.contains("12"))
    }

    @Test func `a brew killed by a signal failed rather than reading as success`() async throws {
        let brew = try FakeExecutable(script: "kill -TERM $$; sleep 5")
        defer { brew.remove() }

        let outcome = await FakeExecutable.runner().run(
            executablePath: brew.path,
            arguments: [],
            environment: [:],
            timeout: 30,
        )

        #expect(!outcome.succeeded)
    }

    // MARK: Missing executable

    /// The app resolves `brew` before it quits, but the path is stale by the time the helper runs it: an
    /// uninstall between the two would leave nothing there.
    @Test func `a path with no executable fails without launching anything`() async {
        let outcome = await FakeExecutable.runner().run(
            executablePath: "/nonexistent/brew",
            arguments: ["upgrade"],
            environment: [:],
            timeout: 30,
        )

        #expect(!outcome.succeeded)
        #expect(outcome.detail.contains("/nonexistent/brew"))
    }

    @Test func `a directory is not an executable`() async {
        let outcome = await FakeExecutable.runner().run(
            executablePath: NSTemporaryDirectory(),
            arguments: ["upgrade"],
            environment: [:],
            timeout: 30,
        )

        #expect(!outcome.succeeded)
    }

    // MARK: Timeout

    /// A wedged upgrade must not hold the helper forever: the user is sitting in front of no app at all.
    @Test func `a brew that hangs is stopped and reported as a timeout`() async throws {
        let brew = try FakeExecutable(script: "sleep 30")
        defer { brew.remove() }

        let started = Date()
        let outcome = await FakeExecutable.runner().run(
            executablePath: brew.path,
            arguments: [],
            environment: [:],
            timeout: 0.5,
        )

        #expect(!outcome.succeeded)
        #expect(outcome.detail.contains("did not finish"))
        #expect(Date().timeIntervalSince(started) < 20, "the runner waited for the process instead of killing it")
    }

    /// Real brew is a shell script that forks ruby, which forks `curl` and `git`, and every one of them
    /// inherits the output descriptor. Signal only `brew` and the drain never sees end-of-input, so the
    /// helper hangs on the timeout that was supposed to rescue it — no outcome recorded, no app brought back.
    @Test func `a timeout kills the descendants brew left behind`() async throws {
        let ready = ReadyFile()
        defer { ready.remove() }
        let descendant = Descendant()
        let brew = try FakeExecutable(
            script: """
            sleep \(descendant.seconds) &
            touch "${READY}"
            wait
            """,
        )
        defer { brew.remove() }

        let outcome = await SelfUpgradeRunner(
            commandRunner: BrewCommandService(),
            sleep: ready.reached,
        ).run(
            executablePath: brew.path,
            arguments: [],
            environment: ["READY": ready.path],
            timeout: 0.5,
        )

        #expect(!outcome.succeeded)
        #expect(outcome.detail.contains("did not finish"))
        #expect(!descendant.isAlive)
    }

    /// Homebrew traps `SIGTERM`, and `brew upgrade --cask` is replacing an app bundle when it does. Killing
    /// it outright can leave half a bundle in `/Applications` and nothing for the relaunch to open.
    @Test func `a timeout asks brew to stop before killing it`() async throws {
        let ready = ReadyFile()
        let caught = ReadyFile()
        defer {
            ready.remove()
            caught.remove()
        }
        let brew = try FakeExecutable(
            script: """
            trap 'touch "${CAUGHT}"; exit 0' TERM
            sleep 30 &
            touch "${READY}"
            wait
            """,
        )
        defer { brew.remove() }

        _ = await SelfUpgradeRunner(commandRunner: BrewCommandService(), sleep: ready.reached).run(
            executablePath: brew.path,
            arguments: [],
            environment: ["READY": ready.path, "CAUGHT": caught.path],
            timeout: 0.5,
        )

        #expect(caught.exists)
    }

    /// What brew managed to say before it wedged is the only account of why.
    @Test func `output from before a timeout is kept`() async throws {
        let ready = ReadyFile()
        defer { ready.remove() }
        let brew = try FakeExecutable(
            script: """
            echo "==> Downloading"
            touch "${READY}"
            sleep 30
            """,
        )
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        _ = await SelfUpgradeRunner(
            commandRunner: BrewCommandService(),
            transcriptSink: { transcript.append($0) },
            sleep: ready.reached,
        ).run(
            executablePath: brew.path,
            arguments: [],
            environment: ["READY": ready.path],
            timeout: 0.5,
        )

        #expect(transcript.lines == ["==> Downloading"])
    }

    // MARK: Transcript

    @Test func `both streams reach the transcript`() async throws {
        let brew = try FakeExecutable(
            script: """
            echo "==> Downloading"
            echo "Warning: something" >&2
            echo "==> Upgrading"
            """,
        )
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        let outcome = await FakeExecutable.runner(transcriptSink: { transcript.append($0) }).run(
            executablePath: brew.path,
            arguments: [],
            environment: [:],
            timeout: 30,
        )

        #expect(outcome.succeeded)
        #expect(transcript.lines.sorted() == ["==> Downloading", "==> Upgrading", "Warning: something"])
    }

    /// Homebrew's progress output is the last thing written before a hang, so a line without its newline
    /// is exactly the line worth having.
    @Test func `output that never ends in a newline is still captured`() async throws {
        let brew = try FakeExecutable(script: #"printf "no trailing newline""#)
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        _ = await FakeExecutable.runner(transcriptSink: { transcript.append($0) }).run(
            executablePath: brew.path,
            arguments: [],
            environment: [:],
            timeout: 30,
        )

        #expect(transcript.lines == ["no trailing newline"])
    }

    /// Reading only after the process exits deadlocks once the output overruns a pipe buffer, and a real
    /// `brew upgrade --cask` writes far more than one.
    @Test func `output larger than a pipe buffer does not deadlock`() async throws {
        let brew = try FakeExecutable(script: "for i in $(seq 1 5000); do echo \"line ${i} of padding output\"; done")
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        let outcome = await FakeExecutable.runner(transcriptSink: { transcript.append($0) }).run(
            executablePath: brew.path,
            arguments: [],
            environment: [:],
            timeout: 60,
        )

        #expect(outcome.succeeded)
        #expect(transcript.lines.count == 5000)
    }

    // MARK: Arguments and environment

    @Test func `the argv reaches brew verbatim`() async throws {
        let brew = try FakeExecutable(script: #"echo "$@""#)
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        _ = await FakeExecutable.runner(transcriptSink: { transcript.append($0) }).run(
            executablePath: brew.path,
            arguments: ["upgrade", "--cask", "homebrew-app"],
            environment: [:],
            timeout: 30,
        )

        #expect(transcript.lines == ["upgrade --cask homebrew-app"])
    }

    /// The fake `brew` a UI test runs reads its fixture tree from here, and the helper outlives the app it
    /// would otherwise have inherited it from.
    @Test func `pinned environment variables reach brew`() async throws {
        let brew = try FakeExecutable(script: #"echo "${BREW_UITEST_SCENARIO:-unset}""#)
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        _ = await FakeExecutable.runner(transcriptSink: { transcript.append($0) }).run(
            executablePath: brew.path,
            arguments: [],
            environment: ["BREW_UITEST_SCENARIO": "selfUpgradeAvailable"],
            timeout: 30,
        )

        #expect(transcript.lines == ["selfUpgradeAvailable"])
    }

    @Test func `the inherited environment survives alongside the pinned one`() async throws {
        let brew = try FakeExecutable(script: #"echo "${PATH}""#)
        defer { brew.remove() }

        let transcript = TranscriptRecorder()
        _ = await FakeExecutable.runner(transcriptSink: { transcript.append($0) }).run(
            executablePath: brew.path,
            arguments: [],
            environment: ["PINNED": "yes"],
            timeout: 30,
        )

        #expect(transcript.lines == [ProcessInfo.processInfo.environment["PATH"]])
    }

    /// The transcript is a file, so escape codes in it are noise rather than colour.
    @Test func `colour is switched off for the transcript`() {
        let environment = SelfUpgradeRunner.pinnedEnvironment(adding: [:])

        #expect(environment["HOMEBREW_NO_COLOR"] == "1")
        #expect(environment["HOMEBREW_NO_ENV_HINTS"] == "1")
    }

    /// A caller that pins one of them means it, even though nothing does today.
    @Test func `a pinned value wins over the defaults`() {
        let environment = SelfUpgradeRunner.pinnedEnvironment(adding: ["HOMEBREW_NO_COLOR": "0"])

        #expect(environment["HOMEBREW_NO_COLOR"] == "0")
    }

    // MARK: Spawning route

    @Test func `brew, its argv and the pinned environment are handed to the command runner`() async throws {
        let brew = try FakeExecutable(script: "exit 0")
        defer { brew.remove() }

        let recorder = InvocationRecorder()
        _ = await SelfUpgradeRunner(commandRunner: recorder).run(
            executablePath: brew.path,
            arguments: ["upgrade", "--cask", "homebrew-app"],
            environment: [:],
            timeout: 30,
        )

        let invocation = try #require(await recorder.first)
        #expect(invocation.executableURL.path == brew.path)
        #expect(invocation.arguments == ["upgrade", "--cask", "homebrew-app"])
        #expect(invocation.options.environment["HOMEBREW_NO_COLOR"] == "1")
    }
}

// MARK: - Support

/// A shell script standing in for `brew`. Real enough to exercise spawning, pipes and exit handling.
private struct FakeExecutable {
    let url: URL

    var path: String {
        url.path
    }

    init(script: String) throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fake-brew-\(UUID().uuidString)")
        try "#!/bin/bash\nset -u\n\(script)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Invoked directly, for the reason `BrewCommandExecutionContext.uiTesting(brewURL:)` does the same:
    /// the login shell would source the developer's dotfiles.
    static func runner(transcriptSink: @escaping @Sendable (String) -> Void = { _ in }) -> SelfUpgradeRunner {
        SelfUpgradeRunner(usesLoginShell: false, transcriptSink: transcriptSink)
    }
}

/// Stands in for the clock, so the timeout fires once the fake `brew` has started rather than after a
/// wall-clock guess a loaded machine loses.
private struct ReadyFile {
    let path = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("self-upgrade-ready-\(UUID().uuidString)").path

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var reached: @Sendable (TimeInterval) async throws -> Void {
        { _ in
            while !FileManager.default.fileExists(atPath: path) {
                try await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    func remove() {
        try? FileManager.default.removeItem(atPath: path)
    }
}

/// A `sleep` long enough to be unique to this test, so `pgrep` can tell whether it outlived the run.
private struct Descendant {
    let seconds = Int.random(in: 20000 ..< 30000)

    var isAlive: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "sleep \(seconds)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

/// The sink is called from the drain's own queue and read from the test, so every access to `storage` goes
/// through the lock; nothing else is mutable.
// swiftlint:disable:next unchecked_sendable
private final class TranscriptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(line)
    }
}

private struct RecordedInvocation {
    let executableURL: URL
    let arguments: [String]
    let options: BrewRunOptions
}

private actor InvocationRecorder: BrewCommandRunning {
    private(set) var invocations: [RecordedInvocation] = []

    var first: RecordedInvocation? {
        invocations.first
    }

    func run(executableURL: URL, arguments: [String], options: BrewRunOptions) async throws -> CommandOutput {
        invocations.append(RecordedInvocation(executableURL: executableURL, arguments: arguments, options: options))
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }
}
