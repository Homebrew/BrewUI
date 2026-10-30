@testable import BrewCore
import Testing

struct ServiceCommandsTests {
    @Test(arguments: [
        (["services", "run", "postgresql@17"], "brew services run postgresql@17"),
        (["services", "run", "a b"], "brew services run 'a b'"),
        (["services", "run", "a'b"], "brew services run 'a'\\''b'"),
    ])
    func `command previews preserve literal arguments`(arguments: [String], expected: String) {
        #expect(BrewCommand(operationKind: .serviceControl, arguments: arguments).displayCommand == expected)
    }

    @Test(arguments: [false, true])
    func `starting preserves login registration`(registered: Bool) {
        let service = BrewService(name: "redis", status: "none", running: false, registered: registered, loaded: false)
        #expect(BrewCommands.service(.start, for: service) == [command(registered ? "start" : "run")])
    }

    @Test(arguments: [false, true])
    func `starting a loaded but stopped job unloads it first`(registered: Bool) {
        let service = BrewService(name: "redis", status: "stopped", running: false, registered: registered, loaded: true)
        #expect(BrewCommands.service(.start, for: service) == [stop, command(registered ? "start" : "run")])
    }

    @Test func `starting an active process unloads it first`() {
        let service = BrewService(name: "redis", status: "started", running: true, registered: false, loaded: nil)
        #expect(BrewCommands.service(.start, for: service) == [stop, command("run")])
    }

    @Test(arguments: [Optional(false), Optional(true), nil])
    func `stopping never changes login registration`(registered: Bool?) {
        let service = BrewService(name: "redis", status: "started", running: true, registered: registered)
        #expect(BrewCommands.service(.stop, for: service) == [stop])
    }

    @Test(arguments: [false, true])
    func `restarting a loaded process uses native restart only when registered`(registered: Bool) {
        let service = BrewService(name: "redis", status: "started", running: true, pid: 43210,
                                  registered: registered, schedulable: false, loaded: true)
        #expect(BrewCommands.service(.restart, for: service) == (registered ? [command("restart")] : [stop, command("run")]))
    }

    @Test(arguments: [false, true])
    func `restarting preserves login registration`(registered: Bool) {
        let service = BrewService(name: "redis", status: "started", running: true, registered: registered, loaded: true)
        #expect(BrewCommands.service(.restart, for: service) == [stop, command(registered ? "start" : "run")])
    }

    @Test func `restarting a schedule still verifies the stop separately`() {
        let service = BrewService(name: "redis", status: "started", running: true, pid: 43210,
                                  registered: true, schedulable: true, loaded: true)
        #expect(BrewCommands.service(.restart, for: service) == [stop, command("start")])
    }

    @Test func `a loaded schedule can be stopped without a running process`() {
        let service = BrewService(name: "logrotate", status: "scheduled", running: false, registered: true, schedulable: true, loaded: true)
        #expect(BrewCommands.service(.stop, for: service) == [
            BrewCommand(operationKind: .serviceControl, arguments: ["services", "stop", "--keep", "logrotate"]),
        ])
    }

    @Test(arguments: [BrewServiceAction.start, .restart])
    func `unknown registration does not produce a start plan`(action: BrewServiceAction) {
        let service = BrewService(name: "redis", status: "none", running: false)
        #expect(BrewCommands.service(action, for: service).isEmpty)
    }

    private var stop: BrewCommand {
        command("stop", flags: ["--keep"])
    }

    private func command(_ verb: String, flags: [String] = []) -> BrewCommand {
        BrewCommand(operationKind: .serviceControl, arguments: ["services", verb] + flags + ["redis"])
    }
}
