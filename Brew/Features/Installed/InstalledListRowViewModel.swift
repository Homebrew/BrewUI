//
//  InstalledListRowViewModel.swift
//  Brew
//

import Foundation
import Observation

enum RowVersionPresentation: Equatable {
    case installed(String)
    case upgrade(current: String, latest: String)
}

@Observable
@MainActor
final class InstalledListRowViewModel {
    let package: BrewPackage
    private(set) var upgradeOperationPhase: BrewOperationPhase = .idle
    private let brewCommandCenter: BrewCommandCenter

    var id: String {
        package.id
    }

    var name: String {
        package.name
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

    var versionPresentation: RowVersionPresentation {
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

    var showsUpgradeBusy: Bool {
        if case .running = upgradeOperationPhase {
            return true
        }
        return false
    }

    init(package: BrewPackage, brewCommandCenter: BrewCommandCenter) {
        self.package = package
        self.brewCommandCenter = brewCommandCenter
    }

    func observeRowUpdates() async {
        let operationID = BrewOperationID(package: package)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            upgradeOperationPhase = phase
        }
    }
}
