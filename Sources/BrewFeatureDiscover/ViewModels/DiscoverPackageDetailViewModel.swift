import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

private let installDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

@Observable
@MainActor
final class DiscoverPackageDetailViewModel {
    private(set) var discoveryPackage: DiscoveryBrewPackage
    @ObservationIgnored private let installedRepository: any InstalledPackageStatusReading
    @ObservationIgnored private let brewCommandCenter: any BrewCommandCenter
    @ObservationIgnored private let commandFactory: any BrewMutatingCommandFactory
    @ObservationIgnored private var mutationTask: Task<Void, Never>?

    /// Latest phase from the command center stream (see ``observeInstallUpdates()``); drives install chrome.
    private var operationPhase: BrewOperationPhase = .idle
    /// Keeps the button spinner up after the install finishes until the installed badge resolves (bridges
    /// the gap before ``installedRepository`` re-reads). See ``DiscoverInstallBusyPresentation``.
    private var awaitingInstallResolution = false
    /// Inline message when an install fails; cleared when a new install starts.
    private(set) var installErrorMessage: String?

    /// True while an install for this package is in flight (and bridging until the installed badge appears).
    var isInstalling: Bool {
        DiscoverInstallBusyPresentation.showsInstallBusy(
            phase: operationPhase,
            awaitingResolution: awaitingInstallResolution,
            isInstalled: installedPackage != nil,
        )
    }

    init(
        package: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        discoveryPackage = package
        self.installedRepository = installedRepository
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
    }

    private var installedPackage: InstalledBrewPackage? {
        installedRepository.info(for: discoveryPackage.id)
    }

    /// Hide the entire Install section once the package is installed — Discover has no upgrade/uninstall.
    var showsInstallSection: Bool {
        installedPackage == nil
    }

    var name: String {
        discoveryPackage.displayName
    }

    var packageKind: HomebrewPackageKind {
        discoveryPackage.kind
    }

    var packageKindChrome: PackageKindChrome {
        discoveryPackage.kind.chrome
    }

    var packageDescription: String? {
        let trimmed = discoveryPackage.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var dependencyNames: [String] {
        discoveryPackage.dependencies.map(\.name)
    }

    var stableVersionLabel: String {
        discoveryPackage.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var installs30DayLabel: String {
        discoveryPackage.thirtyDayInstallCount.formatted()
    }

    /// Catalogue search results carry no analytics (zero install count), so the stat is hidden for them.
    var showsInstallMetrics: Bool {
        discoveryPackage.thirtyDayInstallCount > 0
    }

    var homepageURL: URL? {
        let trimmed = discoveryPackage.homepage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }

    var installCommand: String {
        switch discoveryPackage.kind {
        case .formula:
            "brew install \(discoveryPackage.name)"
        case .cask:
            "brew install --cask \(discoveryPackage.name)"
        }
    }

    var installedStatusLabel: String? {
        guard installedPackage != nil else {
            return nil
        }
        return String(localized: "Installed", comment: "Discover package installed status")
    }

    var installedVersionLabel: String? {
        guard let pkg = installedPackage,
              let raw = pkg.linkedKeg ?? pkg.installedVersions.first else { return nil }
        let base = InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
        let showLinked = pkg.installedVersions.count > 1 && pkg.linkedKeg != nil
        return showLinked ? "\(base) (linked)" : base
    }

    var isInstalledVersionOutdated: Bool {
        installedPackage?.outdated ?? false
    }

    var installDateValue: String? {
        guard let pkg = installedPackage, let date = pkg.installDate else { return nil }
        let formatted = installDateFormatter.string(from: date)
        return pkg.pouredFromBottle ? "Poured from bottle — \(formatted)" : formatted
    }

    var installReasonValue: String? {
        guard let pkg = installedPackage else { return nil }
        return pkg.installedOnRequest ? nil : "As dependency"
    }

    var licenseLabel: String? {
        guard let license = installedPackage?.license, !license.isEmpty else { return nil }
        return license
    }

    var tapDisplayValue: String? {
        installedPackage?.tap
    }

    var sourceURL: URL? {
        installedPackage?.formulaSourceURL
    }

    func update(package: DiscoveryBrewPackage) {
        discoveryPackage = package
        operationPhase = .idle
        awaitingInstallResolution = false
        installErrorMessage = nil
    }

    func installSelectedPackage() {
        guard !isInstalling else {
            return
        }
        installErrorMessage = nil
        let operationID = BrewOperationID(kind: packageKind, name: discoveryPackage.name)
        let command = commandFactory.installCommand(kind: packageKind, name: discoveryPackage.name)
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    installErrorMessage = failure.userFacingMessage
                } else {
                    installErrorMessage = Self.userMessage(for: error)
                }
            }
        }
    }

    /// Run while the detail pane shows this package to track install progress.
    func observeInstallUpdates() async {
        let operationID = BrewOperationID(kind: packageKind, name: discoveryPackage.name)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            let wasRunningInstall = operationPhase.isRunningInstall
            operationPhase = phase
            if phase.isRunningInstall {
                awaitingInstallResolution = true
            } else if case .idle = phase, wasRunningInstall {
                awaitingInstallResolution = true
            } else if case .failed = phase {
                awaitingInstallResolution = false
            }
        }
    }

    private static func userMessage(for error: Error) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            return String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Discover detail error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Discover detail generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            return String(
                localized: "Something went wrong while installing this package.",
                comment: "Discover detail generic install error",
            )
        }
    }
}
