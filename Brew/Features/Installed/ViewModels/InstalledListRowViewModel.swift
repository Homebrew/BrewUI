//
//  InstalledListRowViewModel.swift
//  Brew
//

import Foundation
import Observation

enum InstalledListRowVersionPresentation: Equatable {
    case installed(String)
    case upgrade(current: String, latest: String)
}

@Observable
@MainActor
final class InstalledListRowViewModel {
    private(set) var package: InstalledBrewPackage
    private var operationPhase: BrewOperationPhase = .idle
    private(set) var showsUpgradeBusy: Bool = false
    private(set) var showsUninstallBusy: Bool = false
    private let brewCommandCenter: BrewCommandCenter

    var id: String {
        package.id
    }

    var name: String {
        package.displayName
    }

    var kind: InstalledPackageKind {
        package.kind
    }

    var hasDescription: Bool {
        !package.description.isEmpty
    }

    var descriptionText: String {
        package.description
    }

    var installedVersionLabel: String {
        guard let raw = package.installedVersions.first else {
            return "—"
        }
        return InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
    }

    var availableVersionLabel: String? {
        InstalledBrewVersionFormatting.upgradeDisplayLabel(from: package.latestVersion)
    }

    var showsUpdateAvailable: Bool {
        package.outdated && availableVersionLabel != nil
    }

    var versionPresentation: InstalledListRowVersionPresentation {
        if showsUpdateAvailable, let latest = availableVersionLabel {
            return .upgrade(current: installedVersionLabel, latest: latest)
        }
        return .installed(installedVersionLabel)
    }

    var accessibilitySummary: String {
        var parts = [name]
        if hasDescription {
            parts.append(descriptionText)
        }
        parts.append(installedVersionLabel)
        if showsUpdateAvailable, let latest = availableVersionLabel {
            parts.append("Update available to \(latest)")
        } else {
            parts.append("Installed and up to date")
        }
        return parts.joined(separator: ", ")
    }

    /// Single busy presentation state for row chrome.
    var showsOperationBusy: Bool {
        showsUpgradeBusy || showsUninstallBusy
    }

    /// Full VoiceOver summary, including transient mutation state when present.
    var rowAccessibilityLabel: String {
        if showsUpgradeBusy {
            let upgrading = String(localized: "Upgrading", comment: "VoiceOver: package upgrading")
            return "\(accessibilitySummary), \(upgrading)"
        }
        if showsUninstallBusy {
            let uninstalling = String(localized: "Uninstalling", comment: "VoiceOver: package uninstalling")
            return "\(accessibilitySummary), \(uninstalling)"
        }
        return accessibilitySummary
    }

    init(package: InstalledBrewPackage, brewCommandCenter: BrewCommandCenter) {
        self.package = package
        self.brewCommandCenter = brewCommandCenter
    }

    func update(package newPackage: InstalledBrewPackage) {
        guard newPackage != package else {
            return
        }
        package = newPackage
        operationPhase = .idle
        showsUpgradeBusy = false
        showsUninstallBusy = false
    }

    func observeRowUpdates() async {
        let operationID = BrewOperationID(package: package)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            let oldPhase = operationPhase
            operationPhase = phase
            showsUpgradeBusy = InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: oldPhase,
                newPhase: phase,
                isPackageOutdated: package.outdated,
            )
            showsUninstallBusy = InstalledUninstallBusyPresentation.showsUninstallBusy(
                oldPhase: oldPhase,
                newPhase: phase,
            )
        }
    }
}
