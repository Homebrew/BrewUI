import BrewCore
import Foundation

struct ServiceActionsItem {
    let service: BrewService
    let currentUser: String

    var runtimeAction: BrewServiceAction {
        service.running || (service.loaded == true && service.schedulable == true) ? .stop : .start
    }

    var runtimeTitle: LocalizedStringResource {
        runtimeAction == .stop
            ? LocalizedStringResource("Stop", bundle: #bundle, comment: "Service action: stop the selected service")
            : LocalizedStringResource("Start", bundle: #bundle, comment: "Service action: start the selected service")
    }

    var runtimeSummary: LocalizedStringResource {
        runtimeAction == .stop
            ? LocalizedStringResource("Stops this service", bundle: #bundle, comment: "Service stop command summary")
            : LocalizedStringResource("Starts this service", bundle: #bundle, comment: "Service start command summary")
    }

    var runtimeCommands: [String] {
        BrewCommands.service(runtimeAction, for: service).map(\.displayCommand)
    }

    var restartCommands: [String] {
        BrewCommands.service(.restart, for: service).map(\.displayCommand)
    }

    var canRestart: Bool {
        restriction == nil && (service.loaded == true || service.running)
    }

    var restriction: LocalizedStringResource? {
        if !service.isControllable(by: currentUser) {
            return LocalizedStringResource(
                "Only services owned by the current user can be managed here.", bundle: #bundle,
                comment: "Services: other-user and system services remain read-only",
            )
        }
        if service.registered == nil || (service.loaded == nil && !service.running) {
            return LocalizedStringResource(
                "Homebrew hasn't reported enough information to manage this service.", bundle: #bundle,
                comment: "Services: actions are unavailable when registration or load state is unknown",
            )
        }
        return nil
    }
}
