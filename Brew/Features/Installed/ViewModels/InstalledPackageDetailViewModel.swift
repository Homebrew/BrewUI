//
//  InstalledPackageDetailViewModel.swift
//  Brew
//

import Foundation
import Observation

@Observable
@MainActor
final class InstalledPackageDetailViewModel {
    private let brewCommandCenter: any BrewCommandCenter
    private let installedDependentsRepository: any InstalledDependentsRepository
    private let installedInventoryReading: any InstalledInventoryReading
    private var mutationTask: Task<Void, Never>?

    private(set) var package: BrewPackage
    /// Latest phase from the command center stream (see ``observeRowUpdates()``); drives mutation chrome.
    private var operationPhase: BrewOperationPhase = .idle
    /// Inline message when upgrade fails; cleared when a new upgrade starts.
    private(set) var upgradeErrorMessage: String?
    /// Inline message when uninstall fails; cleared when a new uninstall starts.
    private(set) var uninstallErrorMessage: String?

    /// True while upgrade work is in flight (`CONVENTIONS.md` — transparency / guardrails).
    private(set) var isUpgrading: Bool = false
    /// True while uninstall work is in flight.
    private(set) var isUninstalling: Bool = false
    /// Disables both mutation affordances while a package mutation is in progress.
    private(set) var isMutatingPackage: Bool = false

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
        package: BrewPackage,
        brewCommandCenter: any BrewCommandCenter,
        installedDependentsRepository: any InstalledDependentsRepository,
        installedInventoryReading: any InstalledInventoryReading,
    ) {
        self.package = package
        self.brewCommandCenter = brewCommandCenter
        self.installedDependentsRepository = installedDependentsRepository
        self.installedInventoryReading = installedInventoryReading
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
    func update(package newPackage: BrewPackage) {
        guard newPackage != package else {
            return
        }
        package = newPackage
        operationPhase = .idle
        dependencyRelationships = []
        dependentRelationships = []
        showUninstallConfirmation = false
        showUninstallBlockedCallout = false
        clearMutationErrors()
    }

    func upgradeSelectedPackage() {
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = PackageUpgradeCommand(kind: package.kind, name: package.name)
        submitMutation(
            action: .upgrade,
            operationID: operationID,
            command: command,
        )
    }

    func uninstallSelectedPackage() {
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = PackageUninstallCommand(kind: package.kind, name: package.name)
        submitMutation(
            action: .uninstall,
            operationID: operationID,
            command: command,
        )
    }

    /// Run while the installed detail column shows this ``package/id`` (`InstalledListRowView` pattern).
    func observeRowUpdates() async {
        let operationID = BrewOperationID(package: package)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            let oldPhase = operationPhase
            operationPhase = phase
            isUpgrading = InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: oldPhase,
                newPhase: phase,
                isPackageOutdated: package.outdated,
            )
            isUninstalling = InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: oldPhase,
                newPhase: phase,
            )
            isMutatingPackage = isUpgrading || isUninstalling
            if isUninstalling {
                showUninstallBlockedCallout = false
            }
        }
    }

    private func submitMutation(
        action: PackageMutationAction,
        operationID: BrewOperationID,
        command: any BrewMutatingCommand,
    ) {
        guard !isMutatingPackage else {
            return
        }

        clearMutationErrors()
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    setErrorMessage(failure.userFacingMessage, for: action)
                } else {
                    setErrorMessage(Self.userMessage(for: error, fallback: action.genericFailureMessage), for: action)
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

    private static func userMessage(for error: Error, fallback: String) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            return String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Installed detail error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Installed detail generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            return fallback
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
                comment: "Installed detail generic upgrade error",
            )
        case .uninstall:
            String(
                localized: "Something went wrong while uninstalling this package.",
                comment: "Installed detail generic uninstall error",
            )
        }
    }
}
