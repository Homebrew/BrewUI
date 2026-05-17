//
//  InstalledDetailsViewModel.swift
//  Brew
//

import Foundation
import Observation

@Observable
@MainActor
final class InstalledDetailsViewModel {
    private let brewCommandCenter: any BrewCommandCenter
    private let installedDependentsRepository: any InstalledDependentsRepository
    private let installedInventoryReading: any InstalledInventoryReading
    private var upgradeTask: Task<Void, Never>?

    private(set) var package: BrewPackage
    /// Latest phase from the command center stream (see ``observeRowUpdates()``); drives ``isUpgrading`` only.
    private var upgradeOperationPhase: BrewOperationPhase = .idle
    /// Inline message when upgrade fails; cleared when a new upgrade starts.
    private(set) var upgradeErrorMessage: String?

    /// True while upgrade work is in flight (`CONVENTIONS.md` — transparency / guardrails).
    private(set) var isUpgrading: Bool = false

    var packageName: String {
        package.name
    }

    var packageKind: InstalledPackageKind {
        package.kind
    }

    private(set) var dependencyRelationships: [PackageRelationshipItem] = []

    private(set) var dependentRelationships: [PackageRelationshipItem] = []

    /// User-facing command for the currently selected package details.
    var displayCommand: String {
        package.infoCommand
    }

    /// Copyable Terminal command for upgrading this package (`CONVENTIONS.md` — transparency).
    var upgradeDisplayCommand: String {
        package.upgradeCommand
    }

    /// Shown beside the upgrade affordance whenever the package is outdated.
    var showsUpgradeChrome: Bool {
        package.outdated
    }

    var upgradePrimaryButtonTitle: String? {
        package.upgradeButtonTitle
    }

    /// Valid homepage URL for display, if available.
    var homepageURL: URL? {
        package.homepageURL
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
        dependencyRelationships = []
        dependentRelationships = []
        upgradeErrorMessage = nil
    }

    func upgradeSelectedPackage() {
        guard !isUpgrading else {
            return
        }

        upgradeErrorMessage = nil
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = PackageUpgradeCommand(kind: package.kind, name: package.name)

        upgradeTask?.cancel()
        upgradeTask = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    upgradeErrorMessage = failure.userFacingMessage
                } else {
                    upgradeErrorMessage = Self.userMessage(for: error)
                }
            }
        }
    }

    /// Run while the installed detail column shows this ``package/id`` (`InstalledListRowView` pattern).
    func observeRowUpdates() async {
        let operationID = BrewOperationID(package: package)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            let oldPhase = upgradeOperationPhase
            upgradeOperationPhase = phase
            isUpgrading = InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: oldPhase,
                newPhase: phase,
                isPackageOutdated: package.outdated,
            )
        }
    }

    private static func userMessage(for error: Error) -> String {
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
            return String(
                localized: "Something went wrong while upgrading this package.",
                comment: "Installed detail generic upgrade error",
            )
        }
    }
}
