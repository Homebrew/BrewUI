//
//  UninstallPackageItemTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct UninstallPackageItemTests {
    @Test func `display command uses formula uninstall flag`() {
        let item = UninstallPackageItem(package: .fixture(name: "wget", kind: .formula))
        #expect(item.displayCommand == "brew uninstall --formula wget")
    }

    @Test func `display command uses cask uninstall flag`() {
        let item = UninstallPackageItem(package: .fixture(name: "docker", kind: .cask))
        #expect(item.displayCommand == "brew uninstall --cask docker")
    }

    @Test func `confirmation copy uses package name`() {
        let item = UninstallPackageItem(package: .fixture(name: "wget", kind: .formula))
        #expect(item.primaryButtonTitle == "Uninstall")
        #expect(item.confirmationTitle == "Uninstall wget?")
        #expect(item.confirmationMessage == "This will remove wget from this Mac using Homebrew.")
    }
}
