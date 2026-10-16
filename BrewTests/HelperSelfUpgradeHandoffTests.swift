import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
@testable import Homebrew
import Observation
import Testing

@MainActor
struct HelperSelfUpgradeHandoffTests {
    @Test(arguments: [BrewOperationPhase.running(.serviceControl), .reconciling(.serviceControl)])
    func `an unfinished service action blocks handoff when the command centre is idle`(phase: BrewOperationPhase) async {
        let failure = await #expect(throws: (any Error).self) {
            try await makeHandoff(phase: phase).performUpgrade()
        }
        #expect(failure?.localizedDescription == String(
            localized: "Wait for the running Homebrew command to finish, then upgrade the Homebrew app.",
            bundle: .main,
        ))
    }

    @Test(arguments: [BrewOperationPhase.idle, .failed(reason: .serviceControl(.stateNotReached))])
    func `a settled service action permits handoff to reach the executable check`(phase: BrewOperationPhase) async {
        await #expect(throws: LocatorProbe.reached) {
            try await makeHandoff(phase: phase).performUpgrade()
        }
    }

    private func makeHandoff(phase: BrewOperationPhase) -> HelperSelfUpgradeHandoff {
        HelperSelfUpgradeHandoff(
            brewExecutableURL: { throw LocatorProbe.reached },
            commandCenter: NoopBrewCommandCenter.forTesting(),
            servicesRepository: StubServices(phase: phase),
            defaultsKeyPrefix: "test.selfUpgrade",
            relaunchArguments: [],
            relaunchEnvironment: [:],
            upgradeEnvironment: [:],
            logFileURL: FileManager.default.temporaryDirectory.appendingPathComponent("unused-self-upgrade.log"),
        )
    }
}

private enum LocatorProbe: Error {
    case reached
}

@Observable
@MainActor
private final class StubServices: ServicesRepository {
    var state: LoadState<[BrewService], any Error> = .loaded([])
    var refreshFailure: (any Error)?
    var isRefreshing = false
    let operation: BrewServiceOperation?

    init(phase: BrewOperationPhase) {
        operation = BrewServiceOperation(serviceID: "redis", action: .restart, phase: phase)
    }

    func load(forceRefresh _: Bool) async {}
    func perform(_: BrewServiceAction, serviceID _: String) async {}
}
