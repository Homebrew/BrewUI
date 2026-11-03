import BrewCLI
import BrewCore
@testable import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct ServicesRepositoryTests {
    private static let arguments = ["services", "info", "--all", "--json"]
    private static let failure = BrewCommandError.failed(exitCode: 1, stderr: "permission denied")

    @Test func `services map all fields and sort by name`() async throws {
        let repository = makeRepository(MockBrewCommandRunner(responses: [Self.arguments: Self.output("""
        [
          {"name":"postgresql@16","status":"started","running":true,"loaded":true,"pid":43210,"user":"alex","registered":true,"schedulable":false,
           "file":"~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist","log_path":"/tmp/postgresql.log","error_log_path":"/tmp/postgresql.err"},
          {"name":"dnsmasq","status":"error","running":false,"loaded":true,"exit_code":78,"registered":false,"schedulable":true,"unknown":true},
          {"name":"nginx","status":"none","running":false}
        ]
        """)]))
        await repository.load(forceRefresh: false)
        #expect(try #require(repository.state.value) == [
            BrewService(name: "dnsmasq", status: "error", running: false, exitCode: 78, registered: false, schedulable: true, loaded: true),
            BrewService(name: "nginx", status: "none", running: false),
            BrewService(name: "postgresql@16", status: "started", running: true, pid: 43210, user: "alex", registered: true, schedulable: false,
                        file: "~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist", logPath: "/tmp/postgresql.log", errorLogPath: "/tmp/postgresql.err", loaded: true),
        ])
    }

    @Test(arguments: ["", "[]"])
    func `empty output is an empty inventory`(output: String) async throws {
        let repository = makeRepository(SequenceRunner([.success(Self.output(output))]))
        await repository.load(forceRefresh: false)
        #expect(try #require(repository.state.value).isEmpty)
    }

    @Test func `a loaded inventory is cached until forced`() async {
        let runner = SequenceRunner([.success(Self.output("[]")), .success(Self.output("[]"))])
        let repository = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: false)
        #expect(await runner.callCount == 1)
    }

    @Test func `a failed first read runs again on the next load`() async {
        let runner = SequenceRunner([.failure(Self.failure), .success(Self.output("[]"))])
        let repository = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: false)
        #expect(repository.state.value == [])
    }

    @Test func `a failed refresh keeps the loaded inventory`() async {
        let runner = SequenceRunner([.success(Self.output("[]")), .failure(Self.failure)])
        let repository = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: true)
        #expect(repository.state.value == [])
    }

    @Test func `a failed refresh reports its error`() async {
        let runner = SequenceRunner([.success(Self.output("[]")), .failure(Self.failure)])
        let repository = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: true)
        #expect(repository.refreshFailure as? BrewCommandError == Self.failure)
    }

    @Test func `a load during a read shares that read`() async {
        let runner = GatedRunner()
        let repository = makeRepository(runner)
        async let first: Void = repository.load(forceRefresh: false)
        await runner.waitUntilCalled()
        async let second: Void = repository.load(forceRefresh: true)
        await runner.release(with: Self.output("[]"))
        _ = await (first, second)
        #expect(await runner.callCount == 1)
    }

    @Test(arguments: ["not json", "[{\"name\":\"redis\",\"status\":\"started\"}]"])
    func `malformed output is reported as malformed`(output: String) async {
        let repository = makeRepository(MockBrewCommandRunner(responses: [Self.arguments: Self.output(output)]))
        await repository.load(forceRefresh: false)
        #expect(Self.error(in: repository.state) as? BrewRepositoryError == .malformedBrewOutput(command: "services info --all --json"))
    }

    @Test(arguments: ["not json", ""])
    func `a failing command keeps Homebrew's error`(output: String) async {
        let repository = makeRepository(MockBrewCommandRunner(responses: [
            Self.arguments: CommandOutput(standardOutput: output, standardError: "permission denied", terminationStatus: 2),
        ]))
        await repository.load(forceRefresh: false)
        #expect(Self.error(in: repository.state) as? BrewCommandError == .failed(exitCode: 2, stderr: "permission denied"))
    }

    private static func output(_ text: String) -> CommandOutput {
        CommandOutput(standardOutput: text, standardError: "", terminationStatus: 0)
    }

    private static func error(in state: LoadState<[BrewService], any Error>) -> (any Error)? {
        guard case let .failed(error) = state else { return nil }
        return error
    }

    private func makeRepository(_ runner: any BrewCommandRunning) -> BrewServicesRepository {
        BrewServicesRepository(executionContext: BrewCommandExecutionContext(
            commandRunner: runner, locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        ), commandCenter: NoopBrewCommandCenter.forTesting())
    }
}

private actor SequenceRunner: BrewCommandRunning {
    var results: [Result<CommandOutput, any Error>]
    var callCount = 0
    init(_ results: [Result<CommandOutput, any Error>]) {
        self.results = results
    }

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        callCount += 1
        return try results.removeFirst().get()
    }
}

/// Holds the first read open until released, so a test can start a second load while it runs.
/// Later reads answer at once, so a second read fails the count rather than hanging the test.
private actor GatedRunner: BrewCommandRunning {
    private(set) var callCount = 0
    private var pending: [CheckedContinuation<CommandOutput, Never>] = []
    private var calledWaiters: [CheckedContinuation<Void, Never>] = []

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        callCount += 1
        guard callCount == 1 else {
            return CommandOutput(standardOutput: "[]", standardError: "", terminationStatus: 0)
        }
        calledWaiters.forEach { $0.resume() }
        calledWaiters.removeAll()
        return await withCheckedContinuation { pending.append($0) }
    }

    func waitUntilCalled() async {
        guard callCount == 0 else { return }
        await withCheckedContinuation { calledWaiters.append($0) }
    }

    func release(with output: CommandOutput) {
        pending.forEach { $0.resume(returning: output) }
        pending.removeAll()
    }
}
