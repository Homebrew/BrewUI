//
//  InstalledViewModelTestsSupport.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import BrewRepositories
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

// MARK: - Snapshots (one logical assertion per load test)

struct VMStateSnapshot: Equatable {
    var state: InstalledLoadState
    var formulaPackages: [InstalledBrewPackage]
    var caskPackages: [InstalledBrewPackage]
    var selectedPackageID: InstalledBrewPackage.ID?
    var totalPackageCount: Int

    /// Rows cleared, load finished, after a failed `load()`.
    static func emptyAfterLoad(userFacingError: String) -> VMStateSnapshot {
        VMStateSnapshot(
            state: .error(userFacingError),
            formulaPackages: [],
            caskPackages: [],
            selectedPackageID: nil,
            totalPackageCount: 0,
        )
    }
}

@MainActor
func snapshot(_ vm: InstalledViewModel) -> VMStateSnapshot {
    VMStateSnapshot(
        state: vm.state,
        formulaPackages: vm.loadedFormulaPackages,
        caskPackages: vm.loadedCaskPackages,
        selectedPackageID: vm.selectedPackage?.id,
        totalPackageCount: vm.totalPackageCount,
    )
}

@MainActor
func makeInstalledViewModel(repository: BrewInstalledPackagesRepository) -> InstalledViewModel {
    InstalledViewModel(repository: repository)
}

/// Repository that has not loaded yet — stays in `.loading` until `load()` is called.
@MainActor
func unloadedInstalledRepository() -> BrewInstalledPackagesRepository {
    InstalledPackagesTestSupport.repository(commandRunner: MockBrewCommandRunner(responses: [:]))
}

/// Repository whose `brew info` fetch throws `error`; call `load()` to reach `.failed`.
@MainActor
func failingInstalledRepository(error: Error) -> BrewInstalledPackagesRepository {
    InstalledPackagesTestSupport.repository(
        commandRunner: MockBrewCommandRunner(
            behaviors: [["info", "--installed", "--json=v2"]: .throw(error)],
        ),
    )
}

/// Repository whose brew locator fails; call `load()` to reach `.failed` with the missing-Homebrew message.
@MainActor
func missingBrewInstalledRepository() -> BrewInstalledPackagesRepository {
    InstalledPackagesTestSupport.repository(
        commandRunner: MockBrewCommandRunner(responses: [:]),
        locator: MissingBrewExecutableLocator(),
    )
}

struct OddRepositoryError: Error {}

extension InstalledViewModel {
    var loadedFormulaPackages: [InstalledBrewPackage] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.formulaPackages
    }

    var loadedCaskPackages: [InstalledBrewPackage] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.caskPackages
    }
}
