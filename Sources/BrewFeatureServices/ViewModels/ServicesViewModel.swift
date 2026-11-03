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

struct ServicesContent: Equatable, Placeholdable {
    var services: [BrewService]
    var isInventoryEmpty: Bool

    static var placeholder: ServicesContent {
        ServicesContent(
            services: ["placeholder-a", "placeholder-b", "placeholder-c"].map {
                BrewService(name: $0, status: "started", running: true)
            },
            isInventoryEmpty: false,
        )
    }
}

@Observable
@MainActor
final class ServicesViewModel {
    var state: LoadState<ServicesContent, String> {
        switch repository.state {
        case .loading: .loading
        case let .loaded(services): .loaded(ServicesContent(services: visibleServices, isInventoryEmpty: services.isEmpty))
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
        guard let services = repository.state.value else { return nil }
        let count = services.filter(\.running).count
        if count == 1 {
            return LocalizedStringResource("1 running service", bundle: #bundle, comment: "Services subtitle: one running service")
        }
        return LocalizedStringResource("\(count) running services", bundle: #bundle, comment: "Services subtitle: running service count, never one")
    }

    var scope: ServiceScope = .all
    var selectedServiceID: String?
    @ObservationIgnored private let repository: any ServicesRepository
    @ObservationIgnored private let currentUser: String
    private var mutationTask: Task<Void, Never>?

    init(repository: any ServicesRepository, currentUser: String = NSUserName()) {
        self.repository = repository
        self.currentUser = currentUser
    }

    var visibleServices: [BrewService] {
        (repository.state.value ?? []).filter { service in
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

    var actionsItem: ServiceActionsItem? {
        selectedService.map { ServiceActionsItem(service: $0, currentUser: currentUser) }
    }

    var isMutatingService: Bool {
        mutationTask != nil || repository.operation?.phase.isSettled == false
    }

    var actionFailure: String? {
        guard let operation = repository.operation,
              case let .failed(reason) = operation.phase else { return nil }
        return String(localized: "\(operation.serviceID): \(BrewErrorCopy.message(for: reason))", bundle: #bundle,
                      comment: "Services: action failure; %1$@ is the service name, %2$@ is the error detail")
    }

    func perform(_ action: BrewServiceAction) {
        guard !isMutatingService, let item = actionsItem, item.restriction == nil,
              action != .restart || item.canRestart else { return }
        mutationTask = Task { @MainActor [self] in
            defer { mutationTask = nil }
            await repository.perform(action, serviceID: item.service.id)
        }
    }

    func moveSelection(by offset: Int) {
        let services = visibleServices
        guard let index = services.firstIndex(where: { $0.id == activeSelectedServiceID }),
              services.indices.contains(index + offset)
        else { return }
        selectedServiceID = services[index + offset].id
    }

    func clearSelection() {
        selectedServiceID = nil
    }

    func load() async {
        await repository.load(forceRefresh: repository.state.value != nil)
    }

    func refresh() async {
        await repository.load(forceRefresh: true)
    }

    private static func message(for error: any Error) -> String {
        BrewErrorCopy.message(for: error, fallback: String(
            localized: "Couldn't read Homebrew services.", bundle: #bundle,
            comment: "Services: fallback message when reading the service inventory fails",
        ))
    }
}

enum ServiceStatusTone: Equatable {
    case running, failed, inactive

    init(_ service: BrewService) {
        if service.status == "error" {
            self = .failed
        } else {
            self = service.running ? .running : .inactive
        }
    }
}
