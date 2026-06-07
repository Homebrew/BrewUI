//
//  UpdatesViewModelTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

struct UpdatesViewModelTests {
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

    @Test @MainActor func `load failure surfaces user facing brew stderr`() {
        let repository = StubInstalledPackagesRepository(
            state: .failed(BrewCommandError.failed(exitCode: 1, stderr: "formula conflict")),
        )
        let vm = UpdatesViewModel(
            repository: repository,
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )

        guard case let .error(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "formula conflict")
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
    private static func makeViewModel(packages: [InstalledBrewPackage]) -> UpdatesViewModel {
        UpdatesViewModel(
            repository: StubInstalledPackagesRepository(packages: packages),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }
}
