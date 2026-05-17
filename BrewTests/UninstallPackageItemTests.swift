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

    @Test func `blocked copy is nil without dependents`() {
        let item = UninstallPackageItem(package: .fixture(name: "ada-url", kind: .formula))
        #expect(!item.isBlockedByDependents)
        #expect(item.usedByBlockingBadgeTitle == nil)
        #expect(item.uninstallBlockedBannerLead == nil)
        #expect(item.uninstallBlockedBannerBody == nil)
    }

    @Test func `blocked copy uses singular grammar for one dependent`() {
        let item = UninstallPackageItem(
            package: .fixture(name: "ada-url", kind: .formula),
            blockingDependentCount: 1,
        )
        #expect(
            item.uninstallBlockedBannerBody ==
                "1 package above depends on ada-url. Uninstall it first.",
        )
    }

    @Test func `blocked copy uses plural grammar for multiple dependents`() {
        let item = UninstallPackageItem(
            package: .fixture(name: "ada-url", kind: .formula),
            blockingDependentCount: 3,
        )
        #expect(item.isBlockedByDependents)
        #expect(item.usedByBlockingBadgeTitle == "blocking uninstall")
        #expect(item.uninstallBlockedBannerLead == "Can't uninstall yet.")
        #expect(
            item.uninstallBlockedBannerBody ==
                "3 packages above depend on ada-url. Uninstall them first.",
        )
    }
}
