//
//  InstalledPackageDetailViewModel.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

@Observable
@MainActor
final class InstalledPackageDetailViewModel {
    private let brewCommandCenter: any BrewCommandCenter
    private let commandFactory: any BrewMutatingCommandFactory
    private let installedDependentsRepository: any InstalledDependentsRepository
    private let installedInventoryReading: any InstalledInventoryReading
    private let aiEngine: (any AIEngineProtocol)?
    private var mutationTask: Task<Void, Never>?
    @ObservationIgnored private let operationObserver: PackageOperationObserver
    private var operationPhase: BrewOperationPhase = .idle

    private(set) var upgradeImpact: AIUpgradeImpact?
    private(set) var isAnalyzingUpgradeImpact: Bool = false

    private(set) var package: InstalledBrewPackage
    /// Inline message when upgrade fails; cleared when a new upgrade starts.
    private(set) var upgradeErrorMessage: String?
    /// Inline message when uninstall fails; cleared when a new uninstall starts.
    private(set) var uninstallErrorMessage: String?

    var isUpgrading: Bool {
        InstalledUpgradeBusyPresentation.showsUpgradeBusy(phase: operationPhase)
    }

    var isUninstalling: Bool {
        InstalledUninstallBusyPresentation.showsUninstallBusy(phase: operationPhase)
    }

    var isMutatingPackage: Bool {
        isUpgrading || isUninstalling
    }

    var operationSubject: PackageOperationSubject {
        PackageOperationSubject(packageID: package.id, isOutdated: package.outdated, upgradeName: package.upgradeName)
    }

    /// Drives the uninstall confirmation dialog.
    var showUninstallConfirmation: Bool = false
    /// Drives the uninstall-blocked explanation callout.
    var showUninstallBlockedCallout: Bool = false

    var packageName: String {
        package.displayName
    }

    var packageKind: InstalledPackageKind {
        package.kind
    }

    private(set) var dependencyRelationships: [PackageRelationshipItem] = []

    private(set) var dependentRelationships: [PackageRelationshipItem] = []

    /// Presentation mapping for the Details section metadata.
    var metadataItem: PackageDetailMetadataItem {
        PackageDetailMetadataItem(package: package)
    }

    /// Presentation mapping for the Upgrade section.
    var upgradeItem: UpgradePackageItem {
        UpgradePackageItem(package: package)
    }

    /// True when an upgrade is available — mirrors ``InstalledListRowViewModel/showsUpgradeAvailable``.
    var showsUpgradeAvailable: Bool {
        upgradeItem.showsUpgradeChrome
    }

    /// Homebrew marked the formula or cask deprecated.
    var isDeprecated: Bool {
        package.deprecated
    }

    /// Presentation mapping for the Uninstall section.
    var uninstallItem: UninstallPackageItem {
        UninstallPackageItem(package: package, blockingDependentCount: dependentRelationships.count)
    }

    /// Muted, reduced-opacity uninstall button styling while blocked and not actively uninstalling.
    var showsUninstallBlockedPrimaryButtonChrome: Bool {
        uninstallItem.isBlockedByDependents && !isUninstalling
    }

    /// What the primary uninstall control should do when activated.
    var uninstallPrimaryButtonAction: UninstallPrimaryButtonAction {
        uninstallItem.isBlockedByDependents ? .revealBlockedExplanation : .presentConfirmation
    }

    func handleUninstallPrimaryButtonTapped() {
        switch uninstallPrimaryButtonAction {
        case .presentConfirmation:
            showUninstallConfirmation = true
        case .revealBlockedExplanation:
            showUninstallBlockedCallout = true
        }
    }

    /// Valid homepage URL for display, if available.
    var homepageURL: URL? {
        metadataItem.homepageURL
    }

    init(
        package: InstalledBrewPackage,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
        installedDependentsRepository: any InstalledDependentsRepository,
        installedInventoryReading: any InstalledInventoryReading,
        aiEngine: (any AIEngineProtocol)? = nil,
    ) {
        self.package = package
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
        self.installedDependentsRepository = installedDependentsRepository
        self.installedInventoryReading = installedInventoryReading
        self.aiEngine = aiEngine
        operationObserver = PackageOperationObserver(commandCenter: brewCommandCenter)
    }

    func analyzeUpgradeImpact() async {
        guard let aiEngine, showsUpgradeAvailable else { return }
        isAnalyzingUpgradeImpact = true
        let targetVersion = package.latestVersion.isEmpty ? "latest" : package.latestVersion
        let dependents = dependentRelationships.map(\.displayName)
        let impact = await aiEngine.assessUpgradeImpact(
            package: package,
            targetVersion: targetVersion,
            dependents: dependents
        )
        self.upgradeImpact = impact
        self.isAnalyzingUpgradeImpact = false
    }

    func runVerificationCommand(_ command: String) {
        let parts = command.split(separator: " ").map(String.init)
        guard parts.first == "brew" else { return }
        let args = Array(parts.dropFirst())
        guard !args.isEmpty else { return }
        let brewCommand = commandFactory.doctorFixCommand(arguments: args)
        let operationID = BrewOperationID(maintenanceToken: command, displayCommand: command)
        Task {
            try? await brewCommandCenter.perform(brewCommand, id: operationID)
        }
    }

    /// Refreshes both dependency and dependent relationships for the current package.
    func refreshRelationships() async {
        await refreshDependencies()
        await refreshDependents()
    }

    private func refreshDependents() async {
        let dependents = await installedDependentsRepository.installedDependents(for: package.id)
        dependentRelationships = PackageRelationshipItem.dependents(dependents)
        if !uninstallItem.isBlockedByDependents {
            showUninstallBlockedCallout = false
        }
    }

    private func refreshDependencies() async {
        let installedPackageIDs = await installedInventoryReading.installedPackageIDs()
        dependencyRelationships = PackageRelationshipItem.dependencies(
            package.dependencies,
            installedPackageIDs: installedPackageIDs,
        )
    }

    /// Syncs snapshot data for this row (`InstalledListRowViewModel/update(package:)` pattern).
    func update(package newPackage: InstalledBrewPackage) {
        guard newPackage != package else {
            return
        }
        // One view model serves every selection, so drop the old subject's chrome before the reseed.
        if newPackage.id != package.id {
            operationPhase = .idle
        }
        package = newPackage
        showUninstallConfirmation = false
        showUninstallBlockedCallout = false
        clearMutationErrors()
    }

    func upgradeSelectedPackage() {
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = commandFactory.upgradeCommand(kind: package.kind, name: package.upgradeName)
        submitMutation(
            action: .upgrade,
            operationID: operationID,
            command: command,
        )
    }

    func uninstallSelectedPackage() {
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = commandFactory.uninstallCommand(kind: package.kind, name: package.name)
        submitMutation(
            action: .uninstall,
            operationID: operationID,
            command: command,
        )
    }

    func observeRowUpdates() async {
        for await phase in operationObserver.phases(for: operationSubject) {
            operationPhase = phase
            if isUninstalling {
                showUninstallBlockedCallout = false
            }
        }
    }

    private func submitMutation(
        action: PackageMutationAction,
        operationID: BrewOperationID,
        command: BrewCommand,
    ) {
        guard !isMutatingPackage else {
            return
        }

        clearMutationErrors()
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    setErrorMessage(BrewErrorCopy.message(for: failure), for: action)
                } else {
                    setErrorMessage(
                        BrewErrorCopy.message(for: error, fallback: action.genericFailureMessage),
                        for: action,
                    )
                }
            }
        }
    }

    private func clearMutationErrors() {
        upgradeErrorMessage = nil
        uninstallErrorMessage = nil
    }

    private func setErrorMessage(_ message: String, for action: PackageMutationAction) {
        switch action {
        case .upgrade:
            upgradeErrorMessage = message
        case .uninstall:
            uninstallErrorMessage = message
        }
    }
}

private enum PackageMutationAction {
    case upgrade
    case uninstall

    var genericFailureMessage: String {
        switch self {
        case .upgrade:
            String(
                localized: "Something went wrong while upgrading this package.",
                bundle: #bundle,
                comment: "Installed detail generic upgrade error",
            )
        case .uninstall:
            String(
                localized: "Something went wrong while uninstalling this package.",
                bundle: #bundle,
                comment: "Installed detail generic uninstall error",
            )
        }
    }
}
