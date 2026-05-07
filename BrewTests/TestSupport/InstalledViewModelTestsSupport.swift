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
    var formulaRows: [InstalledPackageRow]
    var caskRows: [InstalledPackageRow]
    var selectedPackageID: InstalledPackageRow.ID?
    var totalPackageCount: Int

    /// Rows cleared, load finished, after a failed `load()`.
    static func emptyAfterLoad(userFacingError: String) -> VMStateSnapshot {
        VMStateSnapshot(
            state: .error(userFacingError),
            formulaRows: [],
            caskRows: [],
            selectedPackageID: nil,
            totalPackageCount: 0,
        )
    }
}

@MainActor
func snapshot(_ vm: InstalledViewModel) -> VMStateSnapshot {
    VMStateSnapshot(
        state: vm.state,
        formulaRows: vm.loadedFormulaRows,
        caskRows: vm.loadedCaskRows,
        selectedPackageID: vm.selectedPackageID,
        totalPackageCount: vm.totalPackageCount,
    )
}

@MainActor
func loadViewModel(
    commandRunner: BrewCommandRunning,
    locator: (any BrewExecutableLocating)? = nil,
) async -> InstalledViewModel {
    let repo = InstalledPackagesTestSupport.repository(commandRunner: commandRunner, locator: locator)
    let vm = InstalledViewModel(repository: repo)
    await vm.load()
    return vm
}

struct OddRepositoryError: Error {}

struct StubThrowingRepository: InstalledPackagesRepository {
    let error: Error

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        throw error
    }
}

extension InstalledViewModel {
    var loadedFormulaRows: [InstalledPackageRow] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.formulaRows
    }

    var loadedCaskRows: [InstalledPackageRow] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.caskRows
    }
}
