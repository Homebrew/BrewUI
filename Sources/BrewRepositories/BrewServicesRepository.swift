import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let servicesRepositoryLogger = Logger(subsystem: "Homebrew.BrewUI", category: "BrewServicesRepository")

/// App-scoped service inventory. A loaded read survives tab changes and only runs again when forced;
/// a failed first read runs again on the next load.
@Observable
@MainActor
public final class BrewServicesRepository: ServicesRepository {
    public private(set) var state: LoadState<[BrewService], any Error> = .loading
    public private(set) var refreshFailure: (any Error)?
    public private(set) var isRefreshing = false
    public private(set) var operation: BrewServiceOperation?

    private let executionContext: BrewCommandExecutionContext
    private let commandCenter: any BrewCommandCenter
    private let currentUser: String
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    public init(executionContext: BrewCommandExecutionContext, commandCenter: any BrewCommandCenter, currentUser: String = NSUserName()) {
        self.executionContext = executionContext
        self.commandCenter = commandCenter
        self.currentUser = currentUser
    }

    public func load(forceRefresh: Bool) async {
        if inFlight == nil {
            guard forceRefresh || state.value == nil else { return }
            if state.value == nil {
                state = .loading
            }
            inFlight = Task { @MainActor in
                isRefreshing = true
                defer {
                    isRefreshing = false
                    inFlight = nil
                }
                do {
                    state = try await .loaded(fetch())
                    refreshFailure = nil
                } catch {
                    if state.isLoaded {
                        refreshFailure = error
                    } else {
                        state = .failed(error)
                    }
                }
            }
        }
        await inFlight?.value
    }

    public func perform(_ action: BrewServiceAction, serviceID: String) async {
        guard operation?.phase.isSettled != false else { return }
        setOperation(action, serviceID: serviceID, phase: .running(.serviceControl))
        // Terminal may have changed ownership or login registration since the cached inventory.
        if let failure = await refreshInventory() {
            setOperation(action, serviceID: serviceID, phase: .failed(reason: failure))
            return
        }
        guard let service = state.value?.first(where: { $0.id == serviceID }),
              service.isControllable(by: currentUser),
              canPerform(action, on: service)
        else {
            setOperation(action, serviceID: serviceID, phase: .failed(reason: .serviceControl(.unavailable)))
            return
        }
        var failure: OperationFailure?
        do {
            let commands = BrewCommands.service(action, for: service)
            for (index, command) in commands.enumerated() {
                try await commandCenter.perform(command, id: .maintenance(token: "service:" + service.name, displayCommand: command.displayCommand))
                if index < commands.count - 1, let stoppedFailure = await refreshAndVerify(.stop, original: service) {
                    failure = stoppedFailure
                    break
                }
            }
        } catch {
            failure = OperationFailure(catching: error)
        }
        setOperation(action, serviceID: serviceID, phase: .reconciling(.serviceControl))
        let finalFailure = await refreshAndVerify(action, original: service)
        failure = failure ?? finalFailure
        setOperation(action, serviceID: serviceID, phase: failure.map { .failed(reason: $0) } ?? .idle)
    }

    private func refreshInventory() async -> OperationFailure? {
        // An earlier read may still contain the pre-command state. Finish it before forcing a new read.
        await inFlight?.value
        await load(forceRefresh: true)
        if let refreshFailure { return OperationFailure(catching: refreshFailure) }
        if case let .failed(error) = state { return OperationFailure(catching: error) }
        return nil
    }

    private func refreshAndVerify(_ action: BrewServiceAction, original: BrewService) async -> OperationFailure? {
        if let failure = await refreshInventory() { return failure }
        return resultMatches(action, original: original) ? nil : .serviceControl(.stateNotReached)
    }

    private func canPerform(_ action: BrewServiceAction, on service: BrewService) -> Bool {
        let active = service.loaded == true || service.running
        return switch action {
        case .start:
            service.loaded != nil && service.registered != nil && !service.running
                && !(service.schedulable == true && service.loaded == true)
        case .stop:
            active
        case .restart:
            (service.loaded != nil || service.running) && service.registered != nil && active
        }
    }

    private func resultMatches(_ action: BrewServiceAction, original: BrewService) -> Bool {
        guard let service = state.value?.first(where: { $0.id == original.id }),
              original.registered == nil || service.registered == original.registered else { return false }
        if action == .restart, BrewCommands.service(action, for: original).count == 1 {
            guard let pid = service.pid, pid > 0, pid != original.pid else { return false }
        }
        switch action {
        case .stop:
            return !service.running && service.loaded == false
        case .start, .restart:
            return service.status != "error" && (service.running || (service.schedulable == true && service.loaded == true))
        }
    }

    private func setOperation(_ action: BrewServiceAction, serviceID: String, phase: BrewOperationPhase) {
        operation = BrewServiceOperation(serviceID: serviceID, action: action, phase: phase)
    }

    private func fetch() async throws -> [BrewService] {
        let brew = try executionContext.brewExecutableURL()
        let arguments = ["services", "info", "--all", "--json"]
        let output = try await executionContext.commandRunner.run(executableURL: brew, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        // Homebrew exits successfully without printing JSON when --all finds no services.
        if output.standardOutput.isEmpty { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([ServiceDTO].self, from: Data(output.standardOutput.utf8))
                .map {
                    BrewService(
                        name: $0.name, status: $0.status, running: $0.running,
                        pid: $0.pid, exitCode: $0.exitCode, user: $0.user, registered: $0.registered, schedulable: $0.schedulable,
                        file: $0.file, logPath: $0.logPath, errorLogPath: $0.errorLogPath,
                        loaded: $0.loaded,
                    )
                }
                .sorted { $0.name < $1.name }
        } catch {
            servicesRepositoryLogger.error("Failed to decode services: \(String(describing: error), privacy: .public)")
            throw BrewRepositoryError.malformedBrewOutput(command: arguments.joined(separator: " "))
        }
    }
}

private struct ServiceDTO: Decodable {
    let name: String, status: String
    let running: Bool
    let loaded: Bool?
    let pid: Int?, exitCode: Int?
    let user: String?
    let registered: Bool?, schedulable: Bool?
    let file: String?
    let logPath: String?, errorLogPath: String?
}
