//
//  UpgradesViewModelScopeTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

struct UpgradesViewModelScopeTests {
    // MARK: - Filtering

    @Test @MainActor func `scope defaults to all and shows both outdated kinds`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)

        #expect(vm.scope == .all)
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.map(\.name) == ["git"])
        #expect(content.caskPackages.map(\.name) == ["slack"])
        #expect(vm.outdatedCount == 2)
    }

    @Test @MainActor func `scope formulae hides outdated casks`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)

        vm.scope = .formulae

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.map(\.name) == ["git"])
        #expect(content.caskPackages.isEmpty)
        #expect(vm.outdatedCount == 1)
        // The unfiltered total is unaffected by the scope filter.
        #expect(vm.totalOutdatedCount == 2)
    }

    @Test @MainActor func `scope casks hides outdated formulae`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)

        vm.scope = .casks

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.isEmpty)
        #expect(content.caskPackages.map(\.name) == ["slack"])
        #expect(vm.outdatedCount == 1)
    }

    @Test @MainActor func `scope composes with the search query`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "github", kind: .cask, outdated: true),
        ])

        vm.scope = .formulae
        vm.searchQuery = "git"

        // "github" matches the query but is excluded by the formulae scope.
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.map(\.name) == ["git"])
        #expect(vm.outdatedCount == 1)
    }

    // MARK: - Subtitle

    @Test @MainActor func `outdatedSubtitle switches to Showing N of M when scoped`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)

        vm.scope = .formulae

        #expect(vm.outdatedSubtitle == "Showing 1 of 2 upgrades")
    }

    @Test @MainActor func `outdatedSubtitle reports no matches when the scope hides everything`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.scope = .casks

        #expect(vm.outdatedSubtitle == "No matches in 2 outdated packages")
    }

    // MARK: - isFiltering / resetFilters

    @Test @MainActor func `isFiltering reflects scope and search`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)
        #expect(!vm.isFiltering)

        vm.scope = .casks
        #expect(vm.isFiltering)

        vm.scope = .all
        vm.searchQuery = "git"
        #expect(vm.isFiltering)
    }

    @Test @MainActor func `resetFilters clears both the scope and the search`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)
        vm.scope = .casks
        vm.searchQuery = "slack"

        vm.resetFilters()

        #expect(vm.scope == .all)
        #expect(vm.searchQuery.isEmpty)
        #expect(!vm.isFiltering)
    }

    // MARK: - Selection

    @Test @MainActor func `selection falls back to first visible row when scope hides it`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)
        vm.setSelection(.cask(token: "slack"))
        #expect(vm.activeSelectedPackageID == .cask(token: "slack"))

        vm.scope = .formulae
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        // Committed selection is untouched, so widening the scope restores it.
        vm.scope = .all
        #expect(vm.activeSelectedPackageID == .cask(token: "slack"))
    }

    // MARK: - upgradeSelection

    @Test @MainActor func `upgradeSelection is all when unfiltered`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)
        #expect(vm.upgradeSelection == .all)
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade")
    }

    @Test @MainActor func `upgradeSelection maps the scope picker to a kind flag`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)

        vm.scope = .formulae
        #expect(vm.upgradeSelection == .formulae)
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade --formula")

        vm.scope = .casks
        #expect(vm.upgradeSelection == .casks)
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade --cask")
    }

    @Test @MainActor func `upgradeSelection lists visible names when searching`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "github", kind: .cask, outdated: true),
        ])

        vm.searchQuery = "git"

        // Visible rows in display order (formulae then casks): git, github.
        #expect(vm.upgradeSelection == .explicit(["git", "github"]))
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade git github")
    }

    @Test @MainActor func `upgradeSelection prefers names when both a scope and a search are active`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "github", kind: .cask, outdated: true),
        ])

        vm.scope = .formulae
        vm.searchQuery = "git"

        // Search takes precedence: only the visible (scoped + searched) formula name.
        #expect(vm.upgradeSelection == .explicit(["git"]))
    }

    @Test @MainActor func `upgradeSelection falls back to the scope when a search matches nothing`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)

        vm.searchQuery = "no-such-package"

        #expect(vm.outdatedCount == 0)
        #expect(vm.upgradeSelection == .all)
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade")

        vm.scope = .casks
        #expect(vm.upgradeSelection == .casks)
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade --cask")
    }

    // MARK: - bulkUpgradeSummary

    @Test @MainActor func `bulkUpgradeSummary describes the scoped selection`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)
        #expect(vm.bulkUpgradeSummary == "Upgrades every outdated package")

        vm.scope = .formulae
        #expect(vm.bulkUpgradeSummary == "Upgrades every outdated formula")

        vm.scope = .casks
        #expect(vm.bulkUpgradeSummary == "Upgrades every outdated cask")
    }

    @Test @MainActor func `bulkUpgradeSummary counts the searched packages`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "github", kind: .cask, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.searchQuery = "git"
        #expect(vm.bulkUpgradeSummary == "Upgrades the 2 packages matching your search")

        vm.searchQuery = "wget"
        #expect(vm.bulkUpgradeSummary == "Upgrades the 1 package matching your search")

        vm.searchQuery = "no-such-package"
        #expect(vm.bulkUpgradeSummary == "Upgrades every outdated package")
    }

    // MARK: - Empty upgrade action

    @Test @MainActor func `isFilteringOutEveryUpgrade distinguishes hidden upgrades from none`() {
        let vm = Self.makeViewModel(packages: Self.mixedOutdated)
        #expect(!vm.isFilteringOutEveryUpgrade)

        vm.searchQuery = "no-such-package"
        #expect(vm.isFilteringOutEveryUpgrade)
        #expect(vm.emptyUpgradeActionTitle == "Nothing to upgrade here")

        let upToDate = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: false),
        ])
        #expect(!upToDate.isFilteringOutEveryUpgrade)
        #expect(upToDate.emptyUpgradeActionTitle == "Nothing to upgrade")

        upToDate.scope = .casks
        #expect(!upToDate.isFilteringOutEveryUpgrade)
        #expect(upToDate.emptyUpgradeActionTitle == "Nothing to upgrade")
    }

    @Test @MainActor func `scope that hides every upgrade reports the filtered title`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
        ])

        vm.scope = .casks

        #expect(vm.outdatedCount == 0)
        #expect(vm.isFilteringOutEveryUpgrade)
        #expect(vm.emptyUpgradeActionTitle == "Nothing to upgrade here")
    }

    // MARK: - upgradeAll submission

    @Test @MainActor func `upgradeAll submits the scoped selection as both id and command`() async {
        let recorder = SubmitRecordingCommandCenter()
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.mixedOutdated),
            brewCommandCenter: recorder,
            commandFactory: StubMutatingCommandFactory(),
        )
        vm.scope = .formulae

        vm.upgradeAll()
        // `upgradeAll` submits from a detached Task; yield so it runs before polling the recorder.
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        await recorder.waitForSubmitCallCount(1)

        let entries = await recorder.recordedSubmitEntries
        #expect(entries.count == 1)
        #expect(entries.first?.id == .bulkUpgrade(.formulae))
        #expect(entries.first?.kind == .upgradeAll)
    }

    @Test @MainActor func `upgradeAll submits explicit names when searching`() async {
        let recorder = SubmitRecordingCommandCenter()
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: [
                .fixture(name: "git", kind: .formula, outdated: true),
                .fixture(name: "github", kind: .cask, outdated: true),
            ]),
            brewCommandCenter: recorder,
            commandFactory: StubMutatingCommandFactory(),
        )
        vm.searchQuery = "git"

        vm.upgradeAll()
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        await recorder.waitForSubmitCallCount(1)

        let entries = await recorder.recordedSubmitEntries
        #expect(entries.first?.id == .bulkUpgrade(.explicit(["git", "github"])))
    }

    @Test @MainActor func `isUpgradingAny tracks a scoped bulk upgrade id`() async {
        let center = PhaseStreamingScopeCommandCenter()
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.mixedOutdated),
            brewCommandCenter: center,
            commandFactory: StubMutatingCommandFactory(),
        )
        await center.waitForSubscriber()

        await center.emit(id: .bulkUpgrade(.formulae), phase: .running(.upgradeAll))
        await Self.waitUntil { vm.isUpgradingAny }
        #expect(vm.isUpgradingAny)

        await center.emit(id: .bulkUpgrade(.formulae), phase: .idle)
        await Self.waitUntil { !vm.isUpgradingAny }
        #expect(!vm.isUpgradingAny)
    }

    // MARK: - Helpers

    private static var mixedOutdated: [InstalledBrewPackage] {
        [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: false),
            .fixture(name: "slack", kind: .cask, outdated: true),
            .fixture(name: "docker", kind: .cask, outdated: false),
        ]
    }

    @MainActor
    private static func makeViewModel(packages: [InstalledBrewPackage]) -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: packages),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }

    @MainActor
    private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 {
            if condition() { return }
            await Task.yield()
        }
    }
}

/// Live phase stream the scope tests drive by hand — mirrors the one in `UpgradesViewModelTests` but is
/// kept private to this file to avoid cross-file coupling.
private actor PhaseStreamingScopeCommandCenter: BrewCommandCenter {
    typealias PhaseEvent = (BrewOperationID, BrewOperationPhase)

    private let phaseStream: AsyncStream<PhaseEvent>
    private let phaseContinuation: AsyncStream<PhaseEvent>.Continuation
    private var subscribed = false
    private var subscriberWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        let (stream, continuation) = AsyncStream<PhaseEvent>.makeStream()
        phaseStream = stream
        phaseContinuation = continuation
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    @discardableResult
    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_: BrewCommand, id _: BrewOperationID) async throws {}

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<PhaseEvent> {
        subscribed = true
        for waiter in subscriberWaiters {
            waiter.resume()
        }
        subscriberWaiters.removeAll()
        return phaseStream
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }

    func emit(id: BrewOperationID, phase: BrewOperationPhase) {
        phaseContinuation.yield((id, phase))
    }

    func waitForSubscriber() async {
        if subscribed { return }
        await withCheckedContinuation { continuation in
            subscriberWaiters.append(continuation)
        }
    }
}
