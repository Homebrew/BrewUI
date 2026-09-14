//
//  BrewSelfUpgradeStatusProvider.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

/// Reading `inventory.state` in the getter routes SwiftUI observation through the existential.
@Observable
@MainActor
public final class BrewSelfUpgradeStatusProvider: SelfUpgradeStatusProviding {
    private let inventory: any InstalledInventoryObserving
    private let versionReader: any RunningAppVersionReading

    public init(
        inventory: any InstalledInventoryObserving,
        versionReader: any RunningAppVersionReading,
    ) {
        self.inventory = inventory
        self.versionReader = versionReader
    }

    public var selfUpgradeStatus: SelfUpgradeStatus {
        let running = versionReader.runningVersion
        guard let cask = appCask else {
            // Not installed via Homebrew, or the inventory is still loading.
            return .upToDate(runningVersion: running)
        }
        let latest = cask.latestVersion.isEmpty ? nil : cask.latestVersion
        let homepage = URL(string: cask.homepage) ?? SelfUpgradeIdentity.homepageURL
        return SelfUpgradeStatus(
            runningVersion: running,
            latestVersion: latest,
            homepageURL: homepage,
            isUpgradeAvailable: cask.outdated,
        )
    }

    private var appCask: InstalledBrewPackage? {
        (inventory.state.value ?? []).first { package in
            package.kind == .cask && package.name == SelfUpgradeIdentity.caskToken
        }
    }
}

/// Falls back to `"0"` so downstream never compares against an empty string.
public struct BundleAppVersionReader: RunningAppVersionReading {
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public var runningVersion: String {
        (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }
}
