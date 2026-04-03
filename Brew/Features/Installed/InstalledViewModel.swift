//
//  InstalledViewModel.swift
//  Brew
//

import Foundation
import Observation

@Observable
@MainActor
final class InstalledViewModel {
    private(set) var formulaRows: [InstalledPackageRow]
    private(set) var caskRows: [InstalledPackageRow]

    var totalPackageCount: Int {
        formulaRows.count + caskRows.count
    }

    var packageCountSubtitle: String {
        if totalPackageCount == 1 {
            return "1 package"
        }
        return "\(totalPackageCount) packages"
    }

    init(
        formulaRows: [InstalledPackageRow]? = nil,
        caskRows: [InstalledPackageRow]? = nil,
    ) {
        self.formulaRows = formulaRows ?? InstalledViewModelDummyData.formulae
        self.caskRows = caskRows ?? InstalledViewModelDummyData.casks
    }
}
