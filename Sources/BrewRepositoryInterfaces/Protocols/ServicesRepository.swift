import BrewCore

/// App-scoped cached source of the services known to Homebrew.
@MainActor
public protocol ServicesRepository: Sendable {
    var state: LoadState<[BrewService], any Error> { get }
    var refreshFailure: (any Error)? { get }
    var isRefreshing: Bool { get }
    func load(forceRefresh: Bool) async
}
