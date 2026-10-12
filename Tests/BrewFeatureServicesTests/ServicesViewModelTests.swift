import BrewCore
@testable import BrewFeatureServices
import BrewRepositoryInterfaces
import Foundation
import Observation
import Testing

@MainActor
struct ServicesViewModelTests {
    private static let inventory = [
        BrewService(name: "redis", status: "started", running: true),
        BrewService(name: "unbound", status: "error", running: false),
        BrewService(name: "postgresql@17", status: "none", running: false),
    ]

    @Test(arguments: [
        (ServiceScope.all, ["redis", "unbound", "postgresql@17"]),
        (ServiceScope.running, ["redis"]),
        (ServiceScope.stopped, ["unbound", "postgresql@17"]),
    ])
    func `scope filters the visible services`(scope: ServiceScope, expected: [String]) {
        let viewModel = makeViewModel()
        viewModel.scope = scope
        #expect(viewModel.visibleServices.map(\.name) == expected)
    }

    @Test func `a selection hidden by the filter falls back to the first visible service`() {
        let viewModel = makeViewModel()
        viewModel.selectedServiceID = "redis"
        viewModel.scope = .stopped
        #expect(viewModel.selectedService?.name == "unbound")
    }

    @Test func `a selection hidden by the filter returns when the filter is cleared`() {
        let viewModel = makeViewModel()
        viewModel.selectedServiceID = "redis"
        viewModel.scope = .stopped
        viewModel.scope = .all
        #expect(viewModel.selectedService?.name == "redis")
    }

    @Test func `an empty inventory selects nothing`() {
        let viewModel = makeViewModel(state: .loaded([]))
        #expect(viewModel.selectedService == nil)
    }

    @Test func `a filter that hides every service is distinct from an empty inventory`() {
        let viewModel = makeViewModel(state: .loaded([Self.inventory[0]]))
        viewModel.scope = .stopped
        #expect(viewModel.state.value == ServicesContent(services: [], isInventoryEmpty: false))
    }

    @Test func `moving down selects the next visible service`() {
        let viewModel = makeViewModel()
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedService?.name == "unbound")
    }

    @Test func `moving up from the first service keeps it selected`() {
        let viewModel = makeViewModel()
        viewModel.moveSelection(by: -1)
        #expect(viewModel.selectedService?.name == "redis")
    }

    @Test func `clearing the selection returns to the first visible service`() {
        let viewModel = makeViewModel()
        viewModel.selectedServiceID = "unbound"
        viewModel.clearSelection()
        #expect(viewModel.selectedService?.name == "redis")
    }

    @Test(arguments: [0, 1, 2])
    func `running subtitle counts the full inventory regardless of filter`(count: Int) {
        let services = (0 ..< count).map { BrewService(name: "service\($0)", status: "started", running: true) }
        let viewModel = makeViewModel(state: .loaded(services))
        viewModel.scope = .stopped
        let expected = count == 1 ? "1 running service" : "\(count) running services"
        #expect(viewModel.runningServiceSubtitle.map { String(localized: $0) } == expected)
    }

    @Test func `a failed read shows the command's error`() {
        let viewModel = makeViewModel(state: .failed(BrewCommandError.failed(exitCode: 1, stderr: "permission denied")))
        guard case let .failed(message) = viewModel.state else {
            Issue.record("Expected a failed state, got \(viewModel.state)")
            return
        }
        #expect(message.contains("permission denied"))
    }

    @Test func `a failed refresh is reported beside the retained inventory`() {
        let repository = StubServices(state: .loaded(Self.inventory))
        repository.refreshFailure = BrewCommandError.failed(exitCode: 1, stderr: "permission denied")
        let viewModel = ServicesViewModel(repository: repository)
        #expect(viewModel.refreshFailure?.contains("permission denied") == true)
    }

    @Test func `the first visit reads without forcing`() async {
        let repository = StubServices(state: .loading)
        await ServicesViewModel(repository: repository).load()
        #expect(repository.loads == [false])
    }

    @Test func `a later visit rereads the cached inventory`() async {
        let repository = StubServices(state: .loaded(Self.inventory))
        await ServicesViewModel(repository: repository).load()
        #expect(repository.loads == [true])
    }

    @Test(arguments: [
        (BrewService(name: "redis", status: "started", running: true), ServiceStatusTone.running),
        (BrewService(name: "unbound", status: "error", running: false), ServiceStatusTone.failed),
        (BrewService(name: "postgresql@17", status: "none", running: false), ServiceStatusTone.inactive),
        (BrewService(name: "backup", status: "scheduled", running: false), ServiceStatusTone.inactive),
    ])
    func `status tone follows Homebrew's status`(service: BrewService, expected: ServiceStatusTone) {
        #expect(ServiceStatusTone(service) == expected)
    }

    private func makeViewModel(state: LoadState<[BrewService], any Error> = .loaded(Self.inventory)) -> ServicesViewModel {
        ServicesViewModel(repository: StubServices(state: state))
    }
}

@Observable
@MainActor
private final class StubServices: ServicesRepository {
    var state: LoadState<[BrewService], any Error>
    var refreshFailure: (any Error)?
    var isRefreshing = false
    private(set) var loads: [Bool] = []

    init(state: LoadState<[BrewService], any Error>) {
        self.state = state
    }

    func load(forceRefresh: Bool) async {
        loads.append(forceRefresh)
    }
}
