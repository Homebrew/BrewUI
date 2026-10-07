import BrewCore
import Observation

public extension PreviewSupport {
    @MainActor
    static func makeServicesRepository() -> any ServicesRepository {
        PreviewServicesRepository()
    }
}

@Observable
@MainActor
private final class PreviewServicesRepository: ServicesRepository {
    let state: LoadState<[BrewService], any Error> = .loaded([
        BrewService(name: "postgresql@17", status: "none", running: false),
        BrewService(name: "redis", status: "started", running: true, user: "user"),
    ])
    let refreshFailure: (any Error)? = nil
    let isRefreshing = false

    func load(forceRefresh _: Bool) async {}
}
