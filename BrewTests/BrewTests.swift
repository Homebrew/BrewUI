//
//  BrewTests.swift
//  BrewTests
//
//  Created by Graeme Arthur on 6/3/2026.
//

@testable import Brew
import Testing

struct BrewTests {
    @Test @MainActor func `installed view model loaded data count`() async {
        let viewModel = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "git", version: "2.45.0"),
                InstalledPackageInfo(name: "node", version: "22.14.0"),
                InstalledPackageInfo(name: "python", version: "3.13.2"),
            ],
            casks: [
                InstalledPackageInfo(name: "visual-studio-code", version: "1.99.0"),
                InstalledPackageInfo(name: "docker", version: "4.39.0"),
            ],
        )
        guard case let .loaded(content) = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(viewModel.totalPackageCount == 5)
        #expect(content.formulaRows.count == 3)
        #expect(content.caskRows.count == 2)
    }
}
