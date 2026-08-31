//
//  UpgradesUpToDateCopyTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

struct UpgradesUpToDateCopyTests {
    @Test @MainActor func `every up-to-date surface renders the same phrase`() {
        // The whole point of the shared copy: the header subtitle, the header action stand-in and the
        // empty-state title/VoiceOver label must not drift into four different claims.
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: false),
            .fixture(name: "wget", kind: .formula, outdated: false),
        ])

        let phrase = UpgradesUpToDateCopy.headline
        #expect(viewModel.outdatedSubtitle == phrase)
        #expect(viewModel.emptyUpgradeActionTitle == phrase)
        #expect(viewModel.upToDateTitle == phrase)
    }

    @Test @MainActor func `detail line reports the installed count it covers`() {
        let none = Self.makeViewModel(packages: [])
        #expect(none.upToDateDetail == "No installed packages to check.")

        let one = Self.makeViewModel(packages: [.fixture(name: "git", kind: .formula, outdated: false)])
        #expect(one.upToDateDetail == "Your installed package is up to date.")

        let many = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: false),
            .fixture(name: "wget", kind: .formula, outdated: false),
            .fixture(name: "slack", kind: .cask, outdated: false),
        ])
        #expect(many.upToDateDetail == "All 3 installed packages are up to date.")
    }

    @Test @MainActor func `detail counts every installed package, not just the up-to-date ones`() {
        // The claim is about the whole inventory the check covers, so outdated rows still count.
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: false),
        ])

        #expect(viewModel.upToDateDetail == "All 2 installed packages are up to date.")
    }

    @Test @MainActor func `filters hiding every upgrade keep their own distinct phrase`() {
        // "Your filters hide everything" is a different claim from "there is nothing to upgrade", so
        // this one must *not* collapse into the shared phrase.
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
        ])

        viewModel.searchQuery = "no-such-package"

        #expect(viewModel.emptyUpgradeActionTitle != UpgradesUpToDateCopy.headline)
        #expect(viewModel.emptyUpgradeActionTitle == "Nothing to upgrade here")
    }

    @MainActor
    private static func makeViewModel(packages: [InstalledBrewPackage]) -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: packages),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }
}
