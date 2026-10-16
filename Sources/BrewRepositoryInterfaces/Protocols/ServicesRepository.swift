import BrewCore
import Observation

/// App-scoped cached source of the services known to Homebrew.
@MainActor
public protocol ServicesRepository: Observable, Sendable {
    var state: LoadState<[BrewService], any Error> { get }
    var refreshFailure: (any Error)? { get }
    var isRefreshing: Bool { get }
    var operation: BrewServiceOperation? { get }
    func load(forceRefresh: Bool) async
    func perform(_ action: BrewServiceAction, serviceID: String) async
}
