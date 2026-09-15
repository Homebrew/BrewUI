//
//  PinPackageItemTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import Foundation
import Testing

struct PinPackageItemTests {
    @Test func `unpinned formula offers brew pin --formula`() {
        let item = PinPackageItem(package: InstalledBrewPackage.fixture(name: "wget", kind: .formula))
        #expect(item.displayCommand == "brew pin --formula wget")
    }

    @Test func `unpinned cask offers brew pin --cask`() {
        let item = PinPackageItem(package: InstalledBrewPackage.fixture(name: "docker", kind: .cask))
        #expect(item.displayCommand == "brew pin --cask docker")
    }

    @Test func `pinned formula offers brew unpin --formula`() {
        var package = InstalledBrewPackage.fixture(name: "wget", kind: .formula)
        package.pinned = true
        let item = PinPackageItem(package: package)
        #expect(item.displayCommand == "brew unpin --formula wget")
    }

    @Test func `pinned cask offers brew unpin --cask`() {
        var package = InstalledBrewPackage.fixture(name: "docker", kind: .cask)
        package.pinned = true
        let item = PinPackageItem(package: package)
        #expect(item.displayCommand == "brew unpin --cask docker")
    }

    @Test func `unpinned package shows Pin titles`() {
        let item = PinPackageItem(package: InstalledBrewPackage.fixture(name: "wget", kind: .formula))
        #expect(item.primaryButtonTitle == "Pin")
        #expect(item.sectionTitle == "Pin")
        #expect(!item.isPinned)
    }

    @Test func `pinned package shows Unpin titles`() {
        var package = InstalledBrewPackage.fixture(name: "wget", kind: .formula)
        package.pinned = true
        let item = PinPackageItem(package: package)
        #expect(item.primaryButtonTitle == "Unpin")
        #expect(item.sectionTitle == "Unpin")
        #expect(item.isPinned)
    }
}
