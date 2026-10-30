import BrewCLI
import BrewCore
@testable import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct ServicesControlTests {
    private static let read = ["services", "info", "--all", "--json"]
    private static let stop = ["services", "stop", "--keep", "redis"]
    private static let run = ["services", "run", "redis"]
    private static let stopped = output("""
    [{"name":"redis","status":"none","running":false,"loaded":false,"registered":false}]
    """)
    private static let running = output("""
    [{"name":"redis","status":"started","running":true,"loaded":true,"registered":false,"user":"alex"}]
    """)
    private static let success = output("")

    @Test func `native restart uses one command and keeps login registration`() async {
        let original = Self.process(pid: 43210, registered: true)
        let runner = ServicesControlRunner([
            .success(original), .success(original), .success(Self.success), .success(Self.process(pid: 43211, registered: true)),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read, ["services", "restart", "redis"], Self.read])
        #expect(repository.operation?.phase == .idle)
    }

    @Test(arguments: [false, true])
    func `restarting an unregistered process verifies a stop and checks login registration`(registered: Bool) async {
        let original = Self.process(pid: 43210)
        let runner = ServicesControlRunner([
            .success(original), .success(original), .success(Self.success), .success(Self.stopped),
            .success(Self.success), .success(Self.process(pid: 43211, registered: registered)),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read, Self.stop, Self.read, Self.run, Self.read])
        #expect(repository.operation?.phase == (registered ? .failed(reason: .serviceControl(.stateNotReached)) : .idle))
    }

    @Test(arguments: [Optional(43210), nil, 0])
    func `native restart requires a new positive PID`(pid: Int?) async {
        let original = Self.process(pid: 43210, registered: true)
        let runner = ServicesControlRunner([.success(original), .success(original), .success(Self.success), .success(Self.process(pid: pid, registered: true))])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(repository.operation?.phase == .failed(reason: .serviceControl(.stateNotReached)))
    }

    @Test func `native restart rejects an unexpected login registration change`() async {
        let original = Self.process(pid: 43210, registered: true)
        let runner = ServicesControlRunner([
            .success(original), .success(original), .success(Self.success), .success(Self.process(pid: 43211)),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(repository.operation?.phase == .failed(reason: .serviceControl(.stateNotReached)))
    }

    @Test func `fresh registration is used when login registration changed outside the app`() async {
        let registered = Self.output("""
        [{"name":"redis","status":"none","running":false,"loaded":false,"registered":true,"user":"alex"}]
        """)
        let runner = ServicesControlRunner([.success(registered), .success(Self.stopped), .success(Self.success), .success(Self.running)])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read, Self.run, Self.read])
        #expect(repository.operation?.phase == .idle)
    }

    @Test func `a failed preflight prevents commands from using cached registration`() async {
        let failure = BrewCommandError.failed(exitCode: 3, stderr: "read failed")
        let runner = ServicesControlRunner([.success(Self.stopped), .failure(failure)])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read])
        #expect(repository.operation?.phase == .failed(reason: .brewCommand(exitCode: 3, stderr: "read failed")))
    }

    @Test(arguments: [nil, false] as [Bool?])
    func `a running service without a confirmed loaded job can restart`(loaded: Bool?) async {
        let running = Self.output("""
        [{"name":"redis","status":"started","running":true,"loaded":\(loaded.map(String.init) ?? "null"),"registered":false,"user":"alex"}]
        """)
        let runner = ServicesControlRunner([
            .success(running), .success(running), .success(Self.success), .success(Self.stopped), .success(Self.success), .success(Self.running),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read, Self.stop, Self.read, Self.run, Self.read])
        #expect(repository.operation?.phase == .idle)
    }

    @Test func `restart does not start again when stop reports success but leaves the job active`() async {
        let runner = ServicesControlRunner([
            .success(Self.running), .success(Self.running), .success(Self.success), .success(Self.running), .success(Self.running),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read, Self.stop, Self.read, Self.read])
        #expect(repository.operation?.phase == .failed(reason: .serviceControl(.stateNotReached)))
    }

    @Test(arguments: [
        "\"user\":\"root\",\"registered\":true,\"loaded\":false",
        "\"user\":\"other\",\"registered\":true,\"loaded\":false",
        "\"registered\":true,\"loaded\":false",
        "\"registered\":false,\"loaded\":false,\"file\":\"/Library/LaunchDaemons/sh.brew.redis.plist\"",
        "\"registered\":false,\"loaded\":false,\"file\":\"/System/Library/LaunchDaemons/sh.brew.redis.plist\"",
        "\"user\":\"alex\",\"loaded\":false",
        "\"user\":\"alex\",\"registered\":false",
    ])
    func `unsafe or unknown services cannot start`(fields: String) async {
        let output = Self.output("[{\"name\":\"redis\",\"status\":\"none\",\"running\":false,\(fields)}]")
        let runner = ServicesControlRunner([.success(output), .success(output)])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read])
    }

    @Test func `service commands use the shared centre and preserve runtime registration`() async {
        let runner = ServicesControlRunner([.success(Self.stopped), .success(Self.stopped), .success(Self.success), .success(Self.running)])
        let (repository, center) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        let entries = await center.recordedSubmitEntries
        #expect(entries.map(\.id) == [.maintenance(token: "service:redis", displayCommand: "brew services run redis")])
        #expect(repository.operation?.phase == .idle)
    }

    @Test func `a failed first restart command skips the second command and refreshes`() async {
        let runner = ServicesControlRunner([
            .success(Self.running), .success(Self.running), .success(CommandOutput(standardOutput: "", standardError: "permission denied", terminationStatus: 1)),
            .success(Self.running),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(await runner.arguments == [Self.read, Self.read, Self.stop, Self.read])
        #expect(repository.operation?.phase == .failed(reason: .brewCommand(exitCode: 1, stderr: "permission denied")))
    }

    @Test func `a failed second restart command retains the stopped inventory and diagnostic`() async {
        let runner = ServicesControlRunner([
            .success(Self.running), .success(Self.running), .success(Self.success), .success(Self.stopped),
            .success(CommandOutput(standardOutput: "start failed", standardError: "", terminationStatus: 2)), .success(Self.stopped),
        ])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.restart, serviceID: "redis")
        #expect(repository.state.value?.first?.running == false)
        #expect(repository.operation?.phase == .failed(reason: .brewCommand(exitCode: 2, stderr: "start failed")))
    }

    @Test func `restart remains busy through both commands and every verification read`() async {
        let runner = ServicesControlRunner([
            .success(Self.running), .success(Self.running), .success(Self.success), .success(Self.stopped), .success(Self.success), .success(Self.running),
        ], gatedCalls: [2, 3, 4, 5, 6])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        let action = Task { await repository.perform(.restart, serviceID: "redis") }
        var phases: [BrewOperationPhase?] = []
        for count in 2 ... 6 {
            await runner.waitUntilCalled(count)
            phases.append(repository.operation?.phase)
            await repository.perform(.stop, serviceID: "redis")
            await runner.release(count)
        }
        await action.value
        #expect(phases == [.running(.serviceControl), .running(.serviceControl), .running(.serviceControl), .running(.serviceControl), .reconciling(.serviceControl)])
        #expect(await runner.arguments == [Self.read, Self.read, Self.stop, Self.read, Self.run, Self.read])
    }

    @Test func `a read started during the command cannot substitute for the final refresh`() async {
        let runner = ServicesControlRunner([
            .success(Self.stopped), .success(Self.stopped), .success(Self.success), .success(Self.stopped), .success(Self.running),
        ], gatedCalls: [3, 4])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        let action = Task { await repository.perform(.start, serviceID: "redis") }
        await runner.waitUntilCalled(3)
        let read = Task { await repository.load(forceRefresh: true) }
        await runner.waitUntilCalled(4)
        await runner.release(3)
        await runner.release(4)
        await read.value
        await action.value
        #expect(await runner.arguments == [Self.read, Self.read, Self.run, Self.read, Self.read])
        #expect(repository.state.value?.first?.running == true)
    }

    @Test(arguments: [
        "[{\"name\":\"redis\",\"status\":\"none\",\"running\":false,\"loaded\":false,\"registered\":false}]",
        "[{\"name\":\"redis\",\"status\":\"started\",\"running\":true,\"loaded\":true,\"registered\":true}]",
    ])
    func `a successful command still fails when runtime or registration is wrong`(finalJSON: String) async {
        let runner = ServicesControlRunner([.success(Self.stopped), .success(Self.stopped), .success(Self.success), .success(Self.output(finalJSON))])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        #expect(repository.operation?.phase == .failed(reason: .serviceControl(.stateNotReached)))
    }

    @Test func `a scheduled job can start without a running process`() async {
        let scheduled = Self.output("""
        [{"name":"redis","status":"stopped","running":false,"loaded":true,"registered":false,"schedulable":true}]
        """)
        let runner = ServicesControlRunner([.success(Self.stopped), .success(Self.stopped), .success(Self.success), .success(scheduled)])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        #expect(repository.operation?.phase == .idle)
    }

    @Test func `a failed final refresh does not report a successful action`() async {
        let failure = BrewCommandError.failed(exitCode: 3, stderr: "read failed")
        let runner = ServicesControlRunner([.success(Self.stopped), .success(Self.stopped), .success(Self.success), .failure(failure)])
        let (repository, _) = makeRepository(runner)
        await repository.load(forceRefresh: false)
        await repository.perform(.start, serviceID: "redis")
        #expect(repository.refreshFailure as? BrewCommandError == failure)
        #expect(repository.operation?.phase == .failed(reason: .brewCommand(exitCode: 3, stderr: "read failed")))
    }

    private static func output(_ text: String) -> CommandOutput {
        CommandOutput(standardOutput: text, standardError: "", terminationStatus: 0)
    }

    private static func process(pid: Int?, registered: Bool = false) -> CommandOutput {
        output("""
        [{"name":"redis","status":"started","running":true,"loaded":true,"pid":\(pid.map(String.init) ?? "null"),
          "registered":\(registered),"schedulable":false,"user":"alex"}]
        """)
    }

    private func makeRepository(_ runner: any BrewCommandRunning) -> (BrewServicesRepository, RecordingSerialBrewCommandCenter) {
        let context = BrewCommandExecutionContext(commandRunner: runner, locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")))
        let center = RecordingSerialBrewCommandCenter(executionContext: context)
        return (BrewServicesRepository(executionContext: context, commandCenter: center, currentUser: "alex"), center)
    }
}

private actor ServicesControlRunner: BrewCommandRunning {
    private var results: [Result<CommandOutput, any Error>]
    private let gatedCalls: Set<Int>
    private var gates: [Int: CheckedContinuation<Void, Never>] = [:]
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var arguments: [[String]] = []

    init(_ results: [Result<CommandOutput, any Error>], gatedCalls: Set<Int> = []) {
        self.results = results
        self.gatedCalls = gatedCalls
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        self.arguments.append(arguments)
        let count = self.arguments.count
        guard !results.isEmpty else { throw BrewCommandError.failed(exitCode: 99, stderr: "Unexpected invocation") }
        let result = results.removeFirst()
        if gatedCalls.contains(count) {
            await withCheckedContinuation { gates[count] = $0; notifyWaiters(count) }
        } else {
            notifyWaiters(count)
        }
        return try result.get()
    }

    func waitUntilCalled(_ count: Int) async {
        guard arguments.count < count else { return }
        await withCheckedContinuation { waiters[count, default: []].append($0) }
    }

    func release(_ count: Int) {
        gates.removeValue(forKey: count)?.resume()
    }

    private func notifyWaiters(_ count: Int) {
        waiters.removeValue(forKey: count)?.forEach { $0.resume() }
    }
}
