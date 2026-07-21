//
//  InstalledViewModelTestsSupport.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

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
