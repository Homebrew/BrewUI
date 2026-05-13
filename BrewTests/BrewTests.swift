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
                .fixture(name: "git", kind: .formula, latestVersion: "2.45.0", installedVersions: ["2.45.0"]),
                .fixture(name: "node", kind: .formula, latestVersion: "22.14.0", installedVersions: ["22.14.0"]),
                .fixture(name: "python", kind: .formula, latestVersion: "3.13.2", installedVersions: ["3.13.2"]),
            ],
            casks: [
                .fixture(
                    name: "visual-studio-code",
                    kind: .cask,
                    latestVersion: "1.99.0",
                    installedVersions: ["1.99.0"],
                ),
                .fixture(name: "docker", kind: .cask, latestVersion: "4.39.0", installedVersions: ["4.39.0"]),
            ],
        )
        guard case let .loaded(content) = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(viewModel.totalPackageCount == 5)
        #expect(content.formulaPackages.count == 3)
        #expect(content.caskPackages.count == 2)
    }
}
