//
//  UpgradePackageItemTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Testing

struct UpgradePackageItemTests {
    @Test func `display command uses formula upgrade flag`() {
        let item = UpgradePackageItem(package: InstalledBrewPackage.fixture(name: "wget", kind: .formula))
        #expect(item.displayCommand == "brew upgrade --formula wget")
    }

    @Test func `display command uses cask upgrade flag`() {
        let item = UpgradePackageItem(package: InstalledBrewPackage.fixture(name: "docker", kind: .cask))
        #expect(item.displayCommand == "brew upgrade --cask docker")
    }

    @Test func `upgrade chrome follows package outdated status`() {
        let outdated = UpgradePackageItem(
            package: InstalledBrewPackage.fixture(name: "wget", latestVersion: "2.0.0", outdated: true),
        )
        #expect(outdated.showsUpgradeChrome)

        let current = UpgradePackageItem(
            package: InstalledBrewPackage.fixture(name: "wget", latestVersion: "2.0.0", outdated: false),
        )
        #expect(!current.showsUpgradeChrome)
    }

    @Test func `primary button title includes normalized version label`() {
        let item = UpgradePackageItem(
            package: InstalledBrewPackage.fixture(name: "wget", latestVersion: "2.0.0", outdated: true),
        )
        #expect(item.primaryButtonTitle == "Upgrade to v2.0.0")
    }

    @Test func `primary button title is nil when no upgrade available`() {
        let item = UpgradePackageItem(
            package: InstalledBrewPackage.fixture(name: "wget", latestVersion: "2.0.0", outdated: false),
        )
        #expect(item.primaryButtonTitle == nil)
    }
}
