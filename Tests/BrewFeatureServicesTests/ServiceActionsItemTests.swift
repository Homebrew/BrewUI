import BrewCore
@testable import BrewFeatureServices
import Foundation
import Testing

struct ServiceActionsItemTests {
    @Test(arguments: [
        (false, false, false, BrewServiceAction.start),
        (true, true, false, BrewServiceAction.stop),
        (false, true, false, BrewServiceAction.start),
        (false, true, true, BrewServiceAction.stop),
    ])
    func `runtime action distinguishes stopped jobs from active schedules`(running: Bool, loaded: Bool, schedulable: Bool, expected: BrewServiceAction) {
        let service = BrewService(name: "redis", status: running ? "started" : "stopped", running: running,
                                  user: "alex", registered: true, schedulable: schedulable, loaded: loaded)
        #expect(ServiceActionsItem(service: service, currentUser: "alex").runtimeAction == expected)
    }

    @Test(arguments: [nil, "root", "another-user"] as [String?])
    func `unverified and other owners remain read only`(user: String?) {
        let service = BrewService(name: "redis", status: "started", running: true, user: user, registered: true, loaded: true)
        #expect(ServiceActionsItem(service: service, currentUser: "alex").restriction != nil)
    }

    @Test func `an unregistered service can start without an owner`() {
        let service = BrewService(name: "redis", status: "none", running: false, registered: false, loaded: false)
        #expect(ServiceActionsItem(service: service, currentUser: "alex").runtimeCommands == ["brew services run redis"])
    }

    @Test(arguments: [false, true])
    func `restarting a running process previews commands that preserve login registration`(registered: Bool) {
        let service = BrewService(name: "redis", status: "started", running: true, pid: 43210, user: "alex",
                                  registered: registered, schedulable: false, loaded: true)
        #expect(ServiceActionsItem(service: service, currentUser: "alex").restartCommands == (registered
                ? ["brew services restart redis"]
                : ["brew services stop --keep redis", "brew services run redis"]))
    }

    @Test func `restarting without a reported PID previews both real commands`() {
        let service = BrewService(name: "redis", status: "started", running: true, user: "alex", registered: false, loaded: true)
        #expect(ServiceActionsItem(service: service, currentUser: "alex").restartCommands == ["brew services stop --keep redis", "brew services run redis"])
    }

    @Test func `an inactive service starts rather than offering restart`() {
        let service = BrewService(name: "redis", status: "none", running: false, user: "alex", registered: true, loaded: false)
        #expect(!ServiceActionsItem(service: service, currentUser: "alex").canRestart)
    }

    @Test func `missing load state disables an inactive service`() {
        let service = BrewService(name: "redis", status: "none", running: false, registered: false)
        #expect(ServiceActionsItem(service: service, currentUser: "alex").restriction != nil)
    }
}
