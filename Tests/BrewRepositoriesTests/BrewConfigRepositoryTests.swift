import BrewCLI
import BrewCore
@testable import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewConfigRepositoryTests {
    private static let configStdout = """
    HOMEBREW_VERSION: 4.3.0
    HOMEBREW_PREFIX: /opt/homebrew
    CPU: 8-core
    """

    @MainActor
    private func repository(
        runner: any BrewCommandRunning,
        environment: [String: String] = [:],
    ) -> BrewConfigRepository {
        BrewConfigRepository(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
            environment: environment,
        )
    }

    @Test @MainActor func `load parses brew config stdout into ordered entries`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0),
        ])

        let repo = repository(runner: runner)
        await repo.load(forceRefresh: false)

        let snapshot = try #require(repo.state.value)
        #expect(snapshot.entries == [
            BrewConfigEntry(key: "HOMEBREW_VERSION", value: "4.3.0"),
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
            BrewConfigEntry(key: "CPU", value: "8-core"),
        ])
    }

    @Test @MainActor func `load merges only HOMEBREW prefixed environment variables, sorted by name`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0),
        ])
        let environment = [
            "HOMEBREW_NO_ANALYTICS": "1",
            "PATH": "/usr/bin",
            "HOMEBREW_CASK_OPTS": "--no-quarantine",
            "HOME": "/Users/test",
        ]

        let repo = repository(runner: runner, environment: environment)
        await repo.load(forceRefresh: false)

        #expect(repo.state.value?.environment == [
            BrewConfigEntry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine"),
            BrewConfigEntry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
    }

    @Test @MainActor func `load surfaces a non-zero exit as a command failure`() async {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: "", standardError: "boom", terminationStatus: 1),
        ])

        let repo = repository(runner: runner)
        await repo.load(forceRefresh: false)

        guard case let .failed(error) = repo.state, let commandError = error as? BrewCommandError else {
            Issue.record("expected .failed with BrewCommandError")
            return
        }
        #expect(commandError == .failed(exitCode: 1, stderr: "boom"))
    }

    @Test @MainActor func `load surfaces a missing brew executable`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let repository = BrewConfigRepository(
            commandRunner: runner,
            locator: MissingBrewExecutableLocator(),
        )

        await repository.load(forceRefresh: false)

        guard case let .failed(error) = repository.state else {
            Issue.record("expected .failed state")
            return
        }
        #expect(error is BrewLookupError)
    }

    @Test @MainActor func `load is a no-op when state is already loaded and forceRefresh is false`() async throws {
        // A runner that only knows one response — a second invocation would throw "unmocked", so if the
        // second `load()` call is a no-op (cache hit) the test passes.
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0),
        ])
        let repo = repository(runner: runner)

        await repo.load(forceRefresh: false)
        let firstSnapshot = try #require(repo.state.value)

        // Second call should hit the cache (not re-invoke the runner).
        await repo.load(forceRefresh: false)
        let secondSnapshot = try #require(repo.state.value)

        #expect(firstSnapshot == secondSnapshot)
    }

    @Test @MainActor func `invalidate marks stale so the next load refetches without forceRefresh`() async throws {
        let runner = SequentialBrewCommandRunner(behaviours: [
            .output(CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0)),
            .output(CommandOutput(
                standardOutput: "HOMEBREW_VERSION: 4.4.0\nCPU: 12-core",
                standardError: "",
                terminationStatus: 0,
            )),
        ])
        let repo = BrewConfigRepository(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )

        await repo.load(forceRefresh: false)
        #expect(repo.state.value?.entries.first?.value == "4.3.0")

        repo.invalidate()
        // The cached value stays visible until the load completes (SWR), but `load(forceRefresh: false)`
        // now refetches because the cache was marked stale.
        await repo.load(forceRefresh: false)

        #expect(repo.state.value?.entries.first?.value == "4.4.0")
    }

    @Test @MainActor func `invalidate leaves the cached state in place`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0),
        ])
        let repo = repository(runner: runner)
        await repo.load(forceRefresh: false)
        let cached = try #require(repo.state.value)

        repo.invalidate()

        // Marking stale doesn't change the visible state — the cached snapshot is still there.
        #expect(repo.state.value == cached)
    }

    @Test @MainActor func `forceRefresh keeps stale state visible when refetch fails`() async throws {
        // First call succeeds; second call (forceRefresh) fails. The cached value should remain visible.
        let runner = SequentialBrewCommandRunner(behaviours: [
            .output(CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0)),
            .throw(BrewCommandError.failed(exitCode: 1, stderr: "transient")),
        ])
        let repo = BrewConfigRepository(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )

        await repo.load(forceRefresh: false)
        let cached = try #require(repo.state.value)

        await repo.load(forceRefresh: true)

        // State stays .loaded with the previously cached snapshot — the failure doesn't clobber it.
        #expect(repo.state.value == cached)
    }
}

/// Returns sequential responses; useful for testing cache-hit vs revalidation behaviour without
/// composing multiple mocks.
private struct SequentialBrewCommandRunner: BrewCommandRunning {
    enum Behaviour: Sendable {
        case output(CommandOutput)
        case `throw`(any Error & Sendable)
    }

    private let behaviours: [Behaviour]
    private let cursor: Cursor

    init(behaviours: [Behaviour]) {
        self.behaviours = behaviours
        cursor = Cursor()
    }

    func run(executableURL _: URL, arguments _: [String]) async throws -> CommandOutput {
        let index = cursor.next()
        let behaviour = behaviours[min(index, behaviours.count - 1)]
        switch behaviour {
        case let .output(output):
            return output
        case let .throw(error):
            throw error
        }
    }

    /// `cursor` is the only mutable state; every access goes through `lock`, so concurrent calls from
    /// the cache-hit test are serialised.
    // swiftlint:disable:next unchecked_sendable
    private final class Cursor: @unchecked Sendable {
        private let lock = NSLock()
        private var index = 0

        func next() -> Int {
            lock.lock()
            defer { lock.unlock() }
            let current = index
            index += 1
            return current
        }
    }
}
