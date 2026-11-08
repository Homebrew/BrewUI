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
    private var operationPhasePackageID: HomebrewPackageID?
    /// Inline message when an install fails; cleared when a new install starts.
    private(set) var installErrorMessage: String?

    // MARK: - AI Enhancements State

    private(set) var alternatives: [AIPackageAlternative] = []
    private(set) var comparisonResult: AIPackageComparison?
    private(set) var comparisonTarget: BrewPackage?
    var isShowingComparison: Bool = false

    /// True while an install is in flight, including the reconcile that lands the badge.
    var isInstalling: Bool {
        let isPhaseBusy = operationPhasePackageID == discoveryPackage.id && DiscoverInstallBusyPresentation.showsInstallBusy(phase: operationPhase)
        return isPhaseBusy || activeInstallingPackageID != nil
    }

    init(
        package: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        discoveryPackage = package
        operationPhasePackageID = package.id
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
        return String(localized: "Installed", bundle: #bundle, comment: "Discover package installed status")
    }

    var installedVersionLabel: String? {
        guard let pkg = installedPackage,
              let raw = pkg.linkedKeg ?? pkg.installedVersions.first else { return nil }
        let base = InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
        let showLinked = pkg.installedVersions.count > 1 && pkg.linkedKeg != nil
        guard showLinked else {
            return base
        }
        return String(
            localized: "\(base) (linked)",
            bundle: #bundle,
            comment: "Installed version label; %@ is the version, annotated when that keg is the linked one",
        )
    }

    var isInstalledVersionOutdated: Bool {
        installedPackage?.outdated ?? false
    }

    var installDateValue: String? {
        guard let pkg = installedPackage, let date = pkg.installDate else { return nil }
        let formatted = installDateFormatter.string(from: date)
        return pkg.pouredFromBottle
            ? String(localized: "Poured from bottle — \(formatted)", bundle: #bundle, comment: "Install date row; %@ is the formatted date")
            : formatted
    }

    var installReasonValue: String? {
        guard let pkg = installedPackage else { return nil }
        return pkg.installedOnRequest
            ? nil
            : String(localized: "As dependency", bundle: #bundle, comment: "Install reason row: installed only because another package needed it")
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

    private var activeComparisonPackageID: DiscoveryBrewPackage.ID?
    private var activeComparisonRequestID: UUID?
    private(set) var activeInstallingPackageID: HomebrewPackageID?

    func isPackageInstalling(_ packageID: HomebrewPackageID) -> Bool {
        if activeInstallingPackageID == packageID {
            return true
        }
        let isPhaseBusy = operationPhasePackageID == discoveryPackage.id && DiscoverInstallBusyPresentation.showsInstallBusy(phase: operationPhase)
        return packageID == discoveryPackage.id && isPhaseBusy
    }

    func update(package: DiscoveryBrewPackage) {
        let samePackage = discoveryPackage.id == package.id
        discoveryPackage = package
        installErrorMessage = nil
        if !samePackage {
            operationPhase = .idle
            operationPhasePackageID = nil
            alternatives = []
            comparisonResult = nil
            comparisonTarget = nil
            isShowingComparison = false
            activeComparisonPackageID = nil
            activeComparisonRequestID = nil
        }
    }

    func installPackage(_ package: BrewPackage) {
        guard !isInstalling else { return }
        installErrorMessage = nil
        activeInstallingPackageID = package.id
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = commandFactory.installCommand(kind: package.kind, name: package.name)
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [self] in
            defer {
                activeInstallingPackageID = nil
            }
            do {
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    installErrorMessage = BrewErrorCopy.message(for: failure)
                } else {
                    installErrorMessage = Self.userMessage(for: error)
                }
            }
        }
    }

    func installSelectedPackage() {
        guard !isInstalling else {
            return
        }
        installErrorMessage = nil
        activeInstallingPackageID = discoveryPackage.id
        let operationID = BrewOperationID(kind: packageKind, name: discoveryPackage.name)
        let command = commandFactory.installCommand(kind: packageKind, name: discoveryPackage.name)
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [self] in
            defer {
                activeInstallingPackageID = nil
            }
            do {
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    installErrorMessage = BrewErrorCopy.message(for: failure)
                } else {
                    installErrorMessage = Self.userMessage(for: error)
                }
            }
        }
    }

    /// Run while the detail pane shows this package to track install progress.
    func observeInstallUpdates() async {
        let observedID = discoveryPackage.id
        let operationID = BrewOperationID(kind: packageKind, name: discoveryPackage.name)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            guard discoveryPackage.id == observedID else { return }
            operationPhase = phase
            operationPhasePackageID = observedID
        }
    }

    private static func userMessage(for error: Error) -> String {
        BrewErrorCopy.message(
            for: error,
            fallback: String(
                localized: "Something went wrong while installing this package.",
                bundle: #bundle,
                comment: "Discover detail generic install error",
            ),
        )
    }
}

// MARK: - AI Alternatives & Comparison

extension DiscoverPackageDetailViewModel {
    func loadAlternatives(using aiEngine: (any AIEngineProtocol)?) async {
        guard let aiEngine else { return }
        let currentID = discoveryPackage.id
        let alts = await aiEngine.suggestAlternatives(for: discoveryPackage.package)
        guard discoveryPackage.id == currentID else { return }
        alternatives = alts
    }

    func compare(
        with targetName: String,
        kind: HomebrewPackageKind = .formula,
        using aiEngine: (any AIEngineProtocol)?,
        catalogue: any CatalogueRepository,
    ) async {
        guard let aiEngine else { return }
        let currentID = discoveryPackage.id
        let requestID = UUID()
        activeComparisonPackageID = currentID
        activeComparisonRequestID = requestID

        let primaryRef = kind == .cask ? HomebrewPackageID.cask(token: targetName) : HomebrewPackageID.formula(name: targetName)
        let fallbackRef = kind == .cask ? HomebrewPackageID.formula(name: targetName) : HomebrewPackageID.cask(token: targetName)

        let foundPrimary = try? await catalogue.package(for: primaryRef)
        let foundTarget: BrewPackage? = if let foundPrimary {
            foundPrimary
        } else {
            try? await catalogue.package(for: fallbackRef)
        }

        guard discoveryPackage.id == currentID, activeComparisonRequestID == requestID else { return }

        let target = foundTarget ?? BrewPackage(
            name: targetName,
            displayName: targetName,
            kind: kind,
            description: "",
            homepage: "",
            latestVersion: "",
            dependencies: [],
        )

        let comparison = await aiEngine.comparePackages(packageA: discoveryPackage.package, packageB: target)
        guard discoveryPackage.id == currentID, activeComparisonRequestID == requestID else { return }

        comparisonResult = comparison
        comparisonTarget = target
        isShowingComparison = true
    }

    func dismissComparison() {
        isShowingComparison = false
    }

    func installAlternative(command: String) {
        guard !isInstalling else { return }
        let isCask = command.contains("--cask")
        let components = command.components(separatedBy: .whitespaces)
        guard let targetName = components.last, !targetName.isEmpty else { return }
        let kind: HomebrewPackageKind = isCask ? .cask : .formula
        installAlternative(name: targetName, kind: kind)
    }

    func installAlternative(name targetName: String, kind: HomebrewPackageKind) {
        guard !isInstalling else { return }
        let pkg = BrewPackage(
            name: targetName,
            displayName: targetName,
            kind: kind,
            description: "",
            homepage: "",
            latestVersion: "",
            dependencies: [],
        )
        installPackage(pkg)
    }
}
