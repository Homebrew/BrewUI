import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

enum ServiceScope: CaseIterable, Hashable {
    case all, running, stopped

    var title: LocalizedStringResource {
        switch self {
        case .all: LocalizedStringResource("All", bundle: #bundle, comment: "Services filter: every service")
        case .running: LocalizedStringResource("Running", bundle: #bundle, comment: "Services filter: running processes")
        case .stopped: LocalizedStringResource("Stopped", bundle: #bundle, comment: "Services filter: services without a running process")
        }
    }
}

@Observable
@MainActor
final class ServicesViewModel {
    var state: LoadState<[BrewService], String> {
        switch repository.state {
        case .loading: .loading
        case let .loaded(services): .loaded(services)
        case let .failed(error): .failed(Self.message(for: error))
        }
    }

    var isRefreshing: Bool {
        repository.isRefreshing
    }

    var refreshFailure: String? {
        repository.refreshFailure.map(Self.message)
    }

    var runningServiceSubtitle: LocalizedStringResource? {
        guard let services = state.value else { return nil }
        let count = services.filter(\.running).count
        if count == 1 {
            return LocalizedStringResource("1 running service", bundle: #bundle, comment: "Services subtitle: one running service")
        }
        return LocalizedStringResource("\(count) running services", bundle: #bundle, comment: "Services subtitle: running service count, never one")
    }

    var scope: ServiceScope = .all
    var selectedServiceID: String?
    @ObservationIgnored private let repository: any ServicesRepository

    init(repository: any ServicesRepository) {
        self.repository = repository
    }

    var visibleServices: [BrewService] {
        (state.value ?? []).filter { service in
            switch scope {
            case .all: true
            case .running: service.running
            case .stopped: !service.running
            }
        }
    }

    var activeSelectedServiceID: String? {
        let services = visibleServices
        return services.first(where: { $0.id == selectedServiceID })?.id ?? services.first?.id
    }

    var selectedService: BrewService? {
        visibleServices.first { $0.id == activeSelectedServiceID }
    }

    func moveSelection(by offset: Int) {
        let services = visibleServices
        guard let index = services.firstIndex(where: { $0.id == activeSelectedServiceID }),
              services.indices.contains(index + offset)
        else { return }
        selectedServiceID = services[index + offset].id
    }

    func load(forceRefresh: Bool = false) async {
        await repository.load(forceRefresh: forceRefresh)
    }

    private static func message(for error: any Error) -> String {
        BrewErrorCopy.message(for: error, fallback: String(
            localized: "Couldn't read Homebrew services.", bundle: #bundle,
            comment: "Services: fallback message when reading the service inventory fails",
        ))
    }
}
