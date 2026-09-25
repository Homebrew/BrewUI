import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let servicesRepositoryLogger = Logger(subsystem: "Homebrew.BrewUI", category: "BrewServicesRepository")

/// App-scoped service inventory. A read survives tab changes and only runs again when forced.
@Observable
@MainActor
public final class BrewServicesRepository: ServicesRepository {
    public private(set) var state: LoadState<[BrewService], any Error> = .loading
    public private(set) var refreshFailure: (any Error)?
    public private(set) var isRefreshing = false

    private let executionContext: BrewCommandExecutionContext
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    public init(executionContext: BrewCommandExecutionContext) {
        self.executionContext = executionContext
    }

    public func load(forceRefresh: Bool) async {
        if inFlight == nil {
            if !forceRefresh {
                guard case .loading = state else { return }
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
                } catch is CancellationError {
                    return
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

    private func fetch() async throws -> [BrewService] {
        let brew = try executionContext.brewExecutableURL()
        let arguments = ["services", "info", "--all", "--json"]
        let output = try await executionContext.commandRunner.run(executableURL: brew, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([ServiceDTO].self, from: Data(output.standardOutput.utf8))
                .map {
                    BrewService(
                        name: $0.name, status: $0.status, running: $0.running,
                        pid: $0.pid, exitCode: $0.exitCode, user: $0.user, registered: $0.registered, schedulable: $0.schedulable,
                        file: $0.file, logPath: $0.logPath, errorLogPath: $0.errorLogPath,
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
    let pid: Int?, exitCode: Int?
    let user: String?
    let registered: Bool?, schedulable: Bool?
    let file: String?
    let logPath: String?, errorLogPath: String?
}
