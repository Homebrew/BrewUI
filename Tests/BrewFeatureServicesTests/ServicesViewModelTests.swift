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
        BrewService(name: "postgresql@17", status: "started", running: false),
    ]

    @Test(arguments: ServiceScope.allCases)
    func `filters and refreshed inventory keep selection visible`(scope: ServiceScope) {
        let repository = StubServices(state: .loaded(Self.inventory))
        let viewModel = ServicesViewModel(repository: repository)
        viewModel.selectedServiceID = "redis"
        viewModel.scope = scope
        let expected: [String] = switch scope {
        case .all: ["redis", "unbound", "postgresql@17"]
        case .running: ["redis"]
        case .stopped: ["unbound", "postgresql@17"]
        }
        #expect(viewModel.visibleServices.map(\.name) == expected)
        #expect(viewModel.selectedService?.name == (scope == .stopped ? "unbound" : "redis"))
        repository.state = .loaded([])
        #expect(viewModel.selectedService == nil)
    }

    @Test(arguments: [0, 1, 2])
    func `running subtitle counts the full inventory regardless of filter`(count: Int) {
        let services = (0 ..< count).map { BrewService(name: "service\($0)", status: "started", running: true) }
        let viewModel = ServicesViewModel(repository: StubServices(state: .loaded(services)))
        viewModel.scope = .stopped
        let expected = count == 1 ? "1 running service" : "\(count) running services"
        #expect(viewModel.runningServiceSubtitle.map { String(localized: $0) } == expected)
    }
}

@Observable
@MainActor
private final class StubServices: ServicesRepository {
    var state: LoadState<[BrewService], any Error>
    var refreshFailure: (any Error)?
    var isRefreshing = false

    init(state: LoadState<[BrewService], any Error>) {
        self.state = state
    }

    func load(forceRefresh _: Bool) async {}
}
