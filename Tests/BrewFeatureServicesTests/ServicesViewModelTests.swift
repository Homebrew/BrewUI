import BrewCore
@testable import BrewFeatureServices
import BrewRepositoryInterfaces
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
        #expect(viewModel.selectedService?.name == (scope == .stopped ? nil : "redis"))
        repository.state = .loaded([])
        #expect(viewModel.selectedService == nil)
    }

    @Test func `initial and refresh errors retain technical details`() {
        let error = BrewCommandError.failed(exitCode: 1, stderr: "permission denied")
        let repository = StubServices(state: .failed(error))
        let viewModel = ServicesViewModel(repository: repository)
        #expect(viewModel.state == .failed("permission denied"))
        repository.state = .loaded(Self.inventory)
        repository.refreshFailure = error
        #expect(viewModel.state == .loaded(Self.inventory))
        #expect(viewModel.refreshFailure == "permission denied")
    }
}

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
