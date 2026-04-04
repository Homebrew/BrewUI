//
//  BrewTests.swift
//  BrewTests
//
//  Created by Graeme Arthur on 6/3/2026.
//

@testable import Brew
import Testing

struct BrewTests {
    @Test @MainActor func `installed view model preview data count`() {
        let viewModel = InstalledViewModel(
            previewFormulae: InstalledViewModelDummyData.formulae,
            previewCasks: InstalledViewModelDummyData.casks,
        )
        #expect(viewModel.totalPackageCount == 5)
        #expect(viewModel.formulaRows.count == 3)
        #expect(viewModel.caskRows.count == 2)
    }
}
