//
//  SelfUpgradeCaskExclusionTests.swift
//  BrewFeatureInstalledTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

/// The app's own cask is upgraded by quitting, replacing the bundle and relaunching. Anywhere it reaches
/// an ordinary `brew upgrade` it would be replaced underneath the running app instead.
@MainActor
struct SelfUpgradeCaskExclusionTests {
    // MARK: The inventory accessors

    @Test func `the app's own cask is recognised, and a formula of the same name is not`() {
        #expect(InstalledBrewPackage.fixture(name: "homebrew-app", kind: .cask).isTheAppsOwnCask)
        #expect(!InstalledBrewPackage.fixture(name: "homebrew-app", kind: .formula).isTheAppsOwnCask)
        #expect(!InstalledBrewPackage.fixture(name: "slack", kind: .cask).isTheAppsOwnCask)
    }

    @Test func `it is kept out of the user-managed inventory and its counts`() {
        let repository = StubInstalledPackagesRepository(packages: Self.packagesIncludingTheApp)

        #expect(repository.userManagedPackages.map(\.name) == ["git", "slack"])
        #expect(repository.outdatedPackages.map(\.name) == ["git"])
        #expect(repository.outdatedCount == 1)
    }

    /// The detector reads `state`, so filtering there would leave the banner unable to see the update.
    @Test func `it is still in the raw state the self-upgrade detector reads`() {
        let repository = StubInstalledPackagesRepository(packages: Self.packagesIncludingTheApp)

        #expect((repository.state.value ?? []).contains { $0.isTheAppsOwnCask })
        #expect(repository.isTheAppsOwnCaskOutdated)
    }

    @Test func `an app cask that is up to date does not trip the bulk guard`() {
        let repository = StubInstalledPackagesRepository(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "homebrew-app", kind: .cask, outdated: false),
        ])

        #expect(!repository.isTheAppsOwnCaskOutdated)
    }

    // MARK: The lists

    @Test func `the Upgrades list leaves it out`() {
        let viewModel = Self.makeUpgradesViewModel(packages: Self.packagesIncludingTheApp)

        guard case let .loaded(content) = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.map(\.name) == ["git"])
        #expect(viewModel.outdatedCount == 1)
        #expect(viewModel.totalOutdatedCount == 1)
        #expect(viewModel.totalInstalledCount == 2)
    }

    @Test func `the Installed list leaves it out`() {
        let viewModel = InstalledViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.packagesIncludingTheApp),
        )

        guard case let .loaded(content) = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.map(\.name) == ["git", "slack"])
        #expect(viewModel.totalPackageCount == 2)
    }

    /// Searching is how a user would go looking for it by name after not finding it in the list.
    @Test func `searching for it by name finds nothing`() {
        let viewModel = Self.makeUpgradesViewModel(packages: Self.packagesIncludingTheApp)

        viewModel.searchQuery = "homebrew-app"

        #expect(viewModel.state.value?.packages.isEmpty == true)
    }

    @Test func `the cask scope shows the other casks but not this one`() {
        let viewModel = Self.makeUpgradesViewModel(packages: [
            .fixture(name: "slack", kind: .cask, outdated: true),
            .fixture(name: "homebrew-app", kind: .cask, outdated: true),
        ])

        viewModel.scope = .casks

        #expect(viewModel.state.value?.packages.map(\.name) == ["slack"])
    }

    // MARK: Upgrade All

    @Test func `upgrade all names the rows rather than sweeping the app's cask in`() {
        let viewModel = Self.makeUpgradesViewModel(packages: Self.packagesIncludingTheApp)

        #expect(viewModel.upgradeSelection == .explicit(["git"]))
        #expect(viewModel.bulkUpgradeDisplayCommand == "brew upgrade git")
    }

    @Test func `the cask scope names the rows too, since bare --cask would sweep it in`() {
        let viewModel = Self.makeUpgradesViewModel(packages: [
            .fixture(name: "slack", kind: .cask, outdated: true),
            .fixture(name: "homebrew-app", kind: .cask, outdated: true),
        ])

        viewModel.scope = .casks

        #expect(viewModel.upgradeSelection == .explicit(["slack"]))
    }

    /// `brew upgrade --formula` cannot reach a cask, so the guard leaves it alone.
    @Test func `the formula scope keeps its plain command`() {
        let viewModel = Self.makeUpgradesViewModel(packages: Self.packagesIncludingTheApp)

        viewModel.scope = .formulae

        #expect(viewModel.upgradeSelection == .formulae)
    }

    @Test func `an inventory without the app's cask keeps the plain bulk commands`() {
        let viewModel = Self.makeUpgradesViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
        ])

        #expect(viewModel.upgradeSelection == .all)

        viewModel.scope = .casks
        #expect(viewModel.upgradeSelection == .casks)
    }

    /// `BrewUpgradeSelection.explicit([])` renders as a bare `brew upgrade`, which upgrades everything.
    @Test func `upgrade all submits nothing when the app's cask is the only outdated package`() async {
        let commandCenter = RecordingCommandCenter()
        let viewModel = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: [
                .fixture(name: "git", kind: .formula, outdated: false),
                .fixture(name: "homebrew-app", kind: .cask, outdated: true),
            ]),
            brewCommandCenter: commandCenter,
            commandFactory: StubMutatingCommandFactory(),
        )

        viewModel.upgradeAll()
        await Self.settle()

        #expect(await commandCenter.submittedArguments.isEmpty)
    }

    @Test func `upgrade all still submits when there are rows to upgrade`() async {
        let commandCenter = RecordingCommandCenter()
        let viewModel = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.packagesIncludingTheApp),
            brewCommandCenter: commandCenter,
            commandFactory: StubMutatingCommandFactory(),
        )

        viewModel.upgradeAll()
        await Self.settle()

        #expect(await commandCenter.submittedArguments == [["upgrade", "git"]])
    }

    // MARK: Helpers

    private static var packagesIncludingTheApp: [InstalledBrewPackage] {
        [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: false),
            .fixture(name: "homebrew-app", kind: .cask, outdated: true),
        ]
    }

    private static func makeUpgradesViewModel(packages: [InstalledBrewPackage]) -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: packages),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }

    /// `upgradeAll` submits from a detached task, so the assertion has to let it run first.
    private static func settle() async {
        for _ in 0 ..< 200 {
            await Task.yield()
        }
    }
}

private actor RecordingCommandCenter: BrewCommandCenter {
    private(set) var submittedArguments: [[String]] = []

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }

    @discardableResult
    func capture(_ command: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        submittedArguments.append(command.arguments)
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id _: BrewOperationID) async throws {
        submittedArguments.append(command.arguments)
    }
}
