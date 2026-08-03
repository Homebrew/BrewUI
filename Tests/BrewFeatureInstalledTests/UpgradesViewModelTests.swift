//
//  UpgradesViewModelTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

struct UpgradesViewModelTests {
    @Test @MainActor func `outdatedPackages filters loaded inventory to outdated rows`() {
        let repository = StubInstalledPackagesRepository(packages: Self.mixedPackages)

        #expect(repository.outdatedCount == 2)
        let names = Set(repository.outdatedPackages.map(\.name))
        #expect(names == ["git", "slack"])
    }

    @Test @MainActor func `state projects only outdated rows`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.map(\.name) == ["git"])
        #expect(content.caskPackages.map(\.name) == ["slack"])
        #expect(vm.outdatedCount == 2)
    }

    @Test @MainActor func `state filters within outdated rows when searching`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        vm.searchQuery = "git"

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.map(\.name) == ["git"])
    }

    @Test @MainActor func `totalOutdatedCount stays unfiltered when search hides every outdated row`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        vm.searchQuery = "zzz-no-match"

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.isEmpty)
        #expect(vm.outdatedCount == 0)
        #expect(vm.totalOutdatedCount == 2)
    }

    @Test @MainActor func `default selection lands on the first row of the interleaved list`() {
        // Casks and formulae share one list ordered as the repository sorted them (by name across
        // kinds), so the alphabetically-first row wins the default selection regardless of kind — here
        // the "alfred" cask, even though a formula follows it.
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "alfred", kind: .cask, outdated: true),
            .fixture(name: "git", kind: .formula, outdated: true),
        ])

        #expect(vm.selectedPackage?.name == "alfred")
    }

    @Test @MainActor func `default selection is the first row when every outdated package is a cask`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "alfred", kind: .cask, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
        ])

        #expect(vm.selectedPackage?.name == "alfred")
    }

    @Test @MainActor func `state stays empty when no outdated rows exist`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "wget", kind: .formula, outdated: false),
            .fixture(name: "docker", kind: .cask, outdated: false),
        ])

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.isEmpty)
        #expect(vm.outdatedCount == 0)
    }

    @Test @MainActor func `outdatedSubtitle renders zero singular and plural copy`() {
        let none = Self.makeViewModel(packages: [
            .fixture(name: "wget", kind: .formula, outdated: false),
        ])
        #expect(none.outdatedSubtitle == "All packages are up to date")

        let one = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
        ])
        #expect(one.outdatedSubtitle == "1 package can be upgraded")

        let many = Self.makeViewModel(packages: Self.mixedPackages)
        #expect(many.outdatedSubtitle == "2 packages can be upgraded")
    }

    @Test @MainActor func `outdatedSubtitle switches to Showing N of M while searching`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        vm.searchQuery = "git"

        #expect(vm.outdatedSubtitle == "Showing 1 of 2 upgrades")
    }

    @Test @MainActor func `outdatedSubtitle calls out hidden upgrades when search matches nothing`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        vm.searchQuery = "zzz-no-match"
        #expect(vm.outdatedSubtitle == "No matches in 2 outdated packages")

        let single = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
        ])
        single.searchQuery = "zzz"
        #expect(single.outdatedSubtitle == "No matches in 1 outdated package")
    }

    @Test @MainActor func `upgradeAll submits exactly one bulk upgrade regardless of outdated count`() async {
        let recorder = SubmitRecordingCommandCenter()
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.mixedPackages),
            brewCommandCenter: recorder,
            commandFactory: StubMutatingCommandFactory(),
        )

        vm.upgradeAll()
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        await recorder.waitForSubmitCallCount(1)

        let entries = await recorder.recordedSubmitEntries
        #expect(entries.count == 1)
        #expect(entries.first?.id == .bulkUpgrade(.all))
        #expect(entries.first?.kind == .upgradeAll)
    }

    @Test @MainActor func `load failure surfaces user facing brew stderr`() {
        let repository = StubInstalledPackagesRepository(
            state: .failed(BrewCommandError.failed(exitCode: 1, stderr: "formula conflict")),
        )
        let vm = UpgradesViewModel(
            repository: repository,
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )

        guard case let .failed(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "formula conflict")
    }

    @Test @MainActor func `bulkUpgradeDisplayCommand mirrors the shared constant`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)
        #expect(vm.bulkUpgradeDisplayCommand == BrewOperationID.bulkUpgradeDisplayCommand)
    }

    @Test @MainActor func `selectInstalledPackage ignores ids that are not visible`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)
        let originalSelection = vm.selectedPackage?.id

        // wget is installed but not outdated, so it isn't in the projected rows.
        vm.selectInstalledPackage(id: .formula(name: "wget"))

        #expect(vm.selectedPackage?.id == originalSelection)
    }

    @Test @MainActor func `setSelection nil resolves to first visible outdated row`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)
        vm.setSelection(.cask(token: "slack"))
        #expect(vm.selectedPackage?.id == .cask(token: "slack"))

        vm.setSelection(nil)

        // Always-on selection — falls back to the first formula in the projected list.
        #expect(vm.selectedPackage?.id == .formula(name: "git"))
    }

    @Test @MainActor
    func `search previews first visible upgrade and restores prior selection when cleared`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "github", kind: .cask, outdated: true),
        ])
        vm.setSelection(.formula(name: "wget"))

        vm.searchQuery = "git"
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        vm.searchQuery = ""
        #expect(vm.activeSelectedPackageID == .formula(name: "wget"))
    }

    @Test @MainActor func `committing a selection during search keeps it after clearing search`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "github", kind: .cask, outdated: true),
        ])
        vm.setSelection(.formula(name: "wget"))

        vm.searchQuery = "git"
        vm.setSelection(.cask(token: "github"))

        vm.searchQuery = ""
        #expect(vm.activeSelectedPackageID == .cask(token: "github"))
    }

    @Test @MainActor func `isUpgradingAny tracks the bulk upgrade phase stream`() async {
        let center = PhaseStreamingCommandCenter()
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.mixedPackages),
            brewCommandCenter: center,
            commandFactory: StubMutatingCommandFactory(),
        )

        // Wait for the observer to subscribe to allPhaseChanges before emitting.
        await center.waitForSubscriber()

        await center.emit(id: .bulkUpgrade(.all), phase: .running(.upgradeAll))
        await Self.waitUntil { vm.isUpgradingAny }
        #expect(vm.isUpgradingAny)

        await center.emit(id: .bulkUpgrade(.all), phase: .idle)
        await Self.waitUntil { !vm.isUpgradingAny }
        #expect(!vm.isUpgradingAny)
    }

    @Test @MainActor func `isUpgradingAny ignores unrelated operations on the shared phase stream`() async {
        let center = PhaseStreamingCommandCenter()
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: Self.mixedPackages),
            brewCommandCenter: center,
            commandFactory: StubMutatingCommandFactory(),
        )

        await center.waitForSubscriber()

        // A single-package install (or any non-bulk op) flowing through the shared command center
        // must not flip the Upgrade All button's disabled state.
        let unrelated = BrewOperationID.package(.formula(name: "wget"))
        await center.emit(id: unrelated, phase: .running(.installFormula))

        // Give the observer a few yields to (incorrectly) react before asserting the negative.
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        #expect(!vm.isUpgradingAny)

        await center.emit(id: unrelated, phase: .idle)
    }

    // MARK: - Keyboard navigation

    @Test @MainActor func `selectNext steps forward through outdated rows and stops at the last`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
        ])
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        let ordered = content.formulaPackages.map(\.id) + content.caskPackages.map(\.id)
        #expect(ordered.count == 3)

        vm.setSelection(ordered[0])
        vm.selectNext()
        #expect(vm.selectedPackage?.id == ordered[1])
        // Crosses the formulae → casks section boundary.
        vm.selectNext()
        #expect(vm.selectedPackage?.id == ordered[2])
        // Clamps at the final row.
        vm.selectNext()
        #expect(vm.selectedPackage?.id == ordered[2])
    }

    @Test @MainActor func `selectPrevious steps backward through outdated rows and stops at the first`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
        ])
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        let ordered = content.formulaPackages.map(\.id) + content.caskPackages.map(\.id)

        vm.setSelection(ordered[2])
        vm.selectPrevious()
        #expect(vm.selectedPackage?.id == ordered[1])
        vm.selectPrevious()
        #expect(vm.selectedPackage?.id == ordered[0])
        vm.selectPrevious()
        #expect(vm.selectedPackage?.id == ordered[0])
    }

    @Test @MainActor func `selectNext and selectPrevious are no-ops when nothing is outdated`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "wget", kind: .formula, outdated: false),
        ])
        #expect(vm.selectedPackage == nil)

        vm.selectNext()
        #expect(vm.selectedPackage == nil)
        vm.selectPrevious()
        #expect(vm.selectedPackage == nil)
    }

    // MARK: - shouldFocusList

    @Test @MainActor func `shouldFocusList is false while the outdated inventory is still loading`() {
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(state: .loading),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(!vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is true once the outdated inventory has loaded`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        #expect(vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is true when loaded with no outdated rows`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "wget", kind: .formula, outdated: false),
        ])

        #expect(vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is false when the inventory load failed`() {
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(state: .failed(OddRepositoryError())),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(!vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is false while the search field is presented`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        vm.isSearchFieldPresented = true

        // The list would otherwise steal focus when it re-appears after a query that filtered every
        // row is deleted; gating on search presentation keeps the cursor in the search box.
        #expect(!vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList returns to true once the search field is dismissed`() {
        let vm = Self.makeViewModel(packages: Self.mixedPackages)

        vm.isSearchFieldPresented = true
        #expect(!vm.shouldFocusList)

        vm.isSearchFieldPresented = false
        #expect(vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList stays false when the search field is presented but not loaded`() {
        let vm = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(state: .loading),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )

        vm.isSearchFieldPresented = true

        #expect(!vm.shouldFocusList)
    }

    // MARK: - Helpers

    private static var mixedPackages: [InstalledBrewPackage] {
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

    /// Yields cooperatively until `condition` flips true, with a bounded budget so a regression
    /// surfaces as a `#expect` failure on the caller's assertion rather than hanging the suite.
    @MainActor
    private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 {
            if condition() { return }
            await Task.yield()
        }
    }
}

/// Live phase stream the test drives by hand — `UpgradesViewModel.observePhaseChanges` subscribes to
/// `allPhaseChanges()` once, then `runningIDs` updates flow from whatever the test emits.
private actor PhaseStreamingCommandCenter: BrewCommandCenter {
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
