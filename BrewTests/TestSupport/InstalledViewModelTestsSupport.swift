//
//  InstalledViewModelTestsSupport.swift
//  BrewTests
//

@testable import Brew
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
func makeInstalledViewModel(
    repository: InstalledPackagesRepository,
    brewCommandCenter: any BrewCommandCenter = NoopBrewCommandCenter.forTesting(),
) -> InstalledViewModel {
    InstalledViewModel(
        repository: repository,
        brewCommandCenter: brewCommandCenter,
    )
}

@MainActor
func loadViewModel(
    commandRunner: BrewCommandRunning,
    locator: (any BrewExecutableLocating)? = nil,
) async -> InstalledViewModel {
    let repository = InstalledPackagesTestSupport.repository(commandRunner: commandRunner, locator: locator)
    let vm = InstalledViewModel(
        repository: repository,
        brewCommandCenter: NoopBrewCommandCenter.forTesting(),
    )
    await vm.load()
    return vm
}

struct OddRepositoryError: Error {}

struct StubThrowingRepository: InstalledPackagesRepository {
    let error: Error

    func loadInstalledPackages(forceRefresh _: Bool) async throws -> [InstalledBrewPackage] {
        throw error
    }
}

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
