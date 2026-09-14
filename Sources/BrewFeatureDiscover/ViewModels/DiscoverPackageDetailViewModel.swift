/*
 * [INPUT]: 依赖 BrewCore 包身份、RepositoryInterfaces 状态与共享展示本地化
 * [OUTPUT]: 提供 DiscoverPackageDetailViewModel
 * [POS]: Discover 展示策略；语言解析不参与仓库或安装任务生命周期
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

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
    private var installFailure: AppMessage?

    func installErrorMessage(localization: AppLocalization = AppLocalization(language: "en")) -> String? {
        installFailure?.string(localization: localization)
    }

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

    func installs30DayLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        discoveryPackage.thirtyDayInstallCount.formatted(.number.locale(localization.locale))
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

    func installedStatusLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String? {
        guard installedPackage != nil else {
            return nil
        }
        return localization.string("Installed")
    }

    func installedVersionLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String? {
        guard let pkg = installedPackage,
              let raw = pkg.linkedKeg ?? pkg.installedVersions.first else { return nil }
        let base = InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
        let showLinked = pkg.installedVersions.count > 1 && pkg.linkedKeg != nil
        return showLinked ? localization.string("\(base) (linked)") : base
    }

    var isInstalledVersionOutdated: Bool {
        installedPackage?.outdated ?? false
    }

    func installDateValue(localization: AppLocalization = AppLocalization(language: "en")) -> String? {
        guard let pkg = installedPackage, let date = pkg.installDate else { return nil }
        let formatted = date.formatted(.dateTime.year().month(.abbreviated).day().locale(localization.locale))
        return pkg.pouredFromBottle ? localization.string("Poured from bottle — \(formatted)") : formatted
    }

    func installReasonValue(localization: AppLocalization = AppLocalization(language: "en")) -> String? {
        guard let pkg = installedPackage else { return nil }
        return pkg.installedOnRequest ? nil : localization.string("As dependency")
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
        installFailure = nil
    }

    func installSelectedPackage() {
        guard !isInstalling else {
            return
        }
        installFailure = nil
        let operationID = BrewOperationID(kind: packageKind, name: discoveryPackage.name)
        let command = commandFactory.installCommand(kind: packageKind, name: discoveryPackage.name)
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    installFailure = AppMessage(failure: failure)
                } else {
                    installFailure = Self.userMessage(for: error)
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

    private static func userMessage(for error: Error) -> AppMessage {
        switch error {
        case BrewLookupError.executableNotFound:
            return .localized("Could not find Homebrew. Install it or ensure brew is in the default location.")
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return .raw(trimmed)
            }
            return .localized("Homebrew command failed.")
        case let BrewCommandError.launchFailed(underlying):
            return .raw(underlying)
        default:
            return .localized("Something went wrong while installing this package.")
        }
    }
}
