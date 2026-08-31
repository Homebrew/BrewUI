//
//  UpgradesViewModelCheckFailureTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

/// "Nothing to upgrade" and "I couldn't find out" look identical from a package list alone. These
/// pin the tab telling them apart.
struct UpgradesViewModelCheckFailureTests {
    private static let brewError = BrewCommandError.failed(exitCode: 1, stderr: "Not a git repository")

    @Test @MainActor func `an empty inventory after a failed check is reported as a failure`() {
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: false),
        ], refreshFailure: Self.brewError)

        #expect(viewModel.showsUpgradeCheckFailure)
        #expect(viewModel.emptyUpgradeActionTitle == "Couldn't check for upgrades")
        #expect(viewModel.outdatedSubtitle == "Couldn't check for upgrades")
        #expect(viewModel.upgradeCheckFailureMessage == "Not a git repository")
        #expect(viewModel.upgradeCheckFailureDetail.hasPrefix("Not a git repository"))
    }

    @Test @MainActor func `an empty inventory after a successful check still claims up to date`() {
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: false),
        ], refreshFailure: nil)

        #expect(!viewModel.showsUpgradeCheckFailure)
        #expect(viewModel.emptyUpgradeActionTitle == UpgradesUpToDateCopy.headline)
        #expect(viewModel.outdatedSubtitle == UpgradesUpToDateCopy.headline)
        #expect(viewModel.upgradeCheckFailureMessage == nil)
    }

    @Test @MainActor func `cached upgrades survive a failed check but stop reading as current`() {
        // There is still a list worth showing; what it must not do is pass the count off as fresh.
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
        ], refreshFailure: Self.brewError)

        #expect(!viewModel.showsUpgradeCheckFailure)
        #expect(viewModel.outdatedCount == 2)
        #expect(viewModel.outdatedSubtitle == "2 packages can be upgraded — last check failed")
    }

    @Test @MainActor func `a failed check does not masquerade as a filtered-out list`() {
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: false),
        ], refreshFailure: Self.brewError)

        #expect(!viewModel.isFilteringOutEveryUpgrade)
        #expect(viewModel.emptyUpgradeActionTitle != "Nothing to upgrade here")
    }

    @Test @MainActor func `filters hiding every upgrade win over a failed check`() {
        // There is known outdated inventory, so the honest explanation for the empty list is the
        // filter, not the failed re-check.
        let viewModel = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
        ], refreshFailure: Self.brewError)

        viewModel.searchQuery = "no-such-package"

        #expect(!viewModel.showsUpgradeCheckFailure)
        #expect(viewModel.emptyUpgradeActionTitle == "Nothing to upgrade here")
    }

    @Test @MainActor func `the failure detail spells out that empty means unknown`() {
        let viewModel = Self.makeViewModel(packages: [], refreshFailure: Self.brewError)

        #expect(
            viewModel.upgradeCheckFailureDetail
                .contains("can't tell whether anything needs upgrading"),
        )
    }

    @Test @MainActor func `a missing brew executable is reported in the tab's own words`() {
        let viewModel = Self.makeViewModel(
            packages: [],
            refreshFailure: BrewLookupError.executableNotFound,
        )

        #expect(viewModel.showsUpgradeCheckFailure)
        #expect(
            viewModel.upgradeCheckFailureMessage
                == "Could not find Homebrew. Install it or ensure brew is in the default location.",
        )
    }

    @MainActor
    private static func makeViewModel(
        packages: [InstalledBrewPackage],
        refreshFailure: (any Error)?,
    ) -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: packages, refreshFailure: refreshFailure),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }
}
