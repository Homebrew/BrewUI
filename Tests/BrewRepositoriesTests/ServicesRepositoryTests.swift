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

    @Test func `services map all fields and sort by name`() async throws {
        let repository = makeRepository(MockBrewCommandRunner(responses: [Self.arguments: Self.output("""
        [
          {"name":"postgresql@16","status":"started","running":true,"pid":43210,"user":"alex","registered":true,"schedulable":false,
           "file":"~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist","log_path":"/tmp/postgresql.log","error_log_path":"/tmp/postgresql.err"},
          {"name":"dnsmasq","status":"error","running":false,"exit_code":78,"registered":false,"schedulable":true,"unknown":true},
          {"name":"nginx","status":"none","running":false}
        ]
        """)]))
        await repository.load(forceRefresh: false)
        #expect(try #require(repository.state.value) == [
            BrewService(name: "dnsmasq", status: "error", running: false, exitCode: 78, registered: false, schedulable: true),
            BrewService(name: "nginx", status: "none", running: false),
            BrewService(name: "postgresql@16", status: "started", running: true, pid: 43210, user: "alex", registered: true, schedulable: false,
                        file: "~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist", logPath: "/tmp/postgresql.log", errorLogPath: "/tmp/postgresql.err"),
        ])
    }

    @Test func `empty inventory is cached until forced`() async throws {
        let runner = SequenceRunner([.success(Self.output("[]")), .success(Self.output("[]"))])
        let repository = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.load(forceRefresh: false)
        #expect(try #require(repository.state.value).isEmpty)
        #expect(await runner.callCount == 1)
    }

    @Test func `failures persist until forced retry and stale data stays visible`() async {
        let failure = BrewCommandError.failed(exitCode: 1, stderr: "permission denied")
        let runner = SequenceRunner([.failure(failure), .success(Self.output("[]")), .failure(failure)])
        let repository = makeRepository(runner)
        await repository.load(forceRefresh: false)
        #expect(Self.error(in: repository.state) as? BrewCommandError == failure)
        await repository.load(forceRefresh: true)
        await repository.load(forceRefresh: true)
        #expect(repository.state.value == [])
        #expect(repository.refreshFailure as? BrewCommandError == failure)
        await repository.load(forceRefresh: false)
        #expect(await runner.callCount == 3)
    }

    @Test(arguments: [("not json", Int32(0), ""), ("[{\"name\":\"redis\",\"status\":\"started\"}]", Int32(0), ""),
                      ("not json", Int32(2), "permission denied")])
    func `malformed and failed commands preserve errors`(output: String, status: Int32, stderr: String) async {
        let repository = makeRepository(MockBrewCommandRunner(responses: [Self.arguments: CommandOutput(standardOutput: output, standardError: stderr, terminationStatus: status)]))
        await repository.load(forceRefresh: false)
        if status == 0 {
            #expect(Self.error(in: repository.state) as? BrewRepositoryError == .malformedBrewOutput(command: "services info --all --json"))
        } else {
            #expect(Self.error(in: repository.state) as? BrewCommandError == .failed(exitCode: 2, stderr: "permission denied"))
        }
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
        ))
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
