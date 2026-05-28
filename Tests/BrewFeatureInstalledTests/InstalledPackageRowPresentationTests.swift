//
//  InstalledPackageRowPresentationTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import BrewUIComponents
import Testing

struct InstalledPackageRowPresentationTests {
    @Test func `id differs by kind for same name`() {
        let formula = InstalledBrewPackage.fixture(name: "foo", kind: .formula)
        let cask = InstalledBrewPackage.fixture(name: "foo", kind: .cask)
        #expect(formula.id != cask.id)
    }

    @Test @MainActor func `row vm formats version labels`() {
        let vm = InstalledListRowViewModel(
            package: InstalledBrewPackage.fixture(
                name: "git",
                kind: .formula,
                latestVersion: "2.1.0",
                installedVersions: ["2.0.0"],
                outdated: true,
            ),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(vm.installedVersionLabel == "v2.0.0")
        #expect(vm.availableVersionLabel == "v2.1.0")
        #expect(vm.versionPresentation == .upgrade(current: "v2.0.0", latest: "v2.1.0"))
    }

    @Test @MainActor func `row vm accessibility summary includes update line`() {
        let vm = InstalledListRowViewModel(
            package: InstalledBrewPackage.fixture(
                name: "Git",
                kind: .formula,
                description: "DVCS",
                latestVersion: "2.1",
                installedVersions: ["2.0"],
                outdated: true,
            ),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(vm.accessibilitySummary == "Git, DVCS, v2.0, Update available to v2.1")
    }

    @Test func `formula chrome matches design tokens`() {
        let expected = PackageKindChrome(
            badgeLabel: "FORMULA",
            accent: .brandPrimary,
            iconBackground: .brandTint,
        )
        #expect(InstalledPackageKind.formula.chrome == expected)
    }

    @Test func `cask chrome matches design tokens`() {
        let expected = PackageKindChrome(
            badgeLabel: "CASK",
            accent: .statusInfo,
            iconBackground: .statusInfoSubtle,
        )
        #expect(InstalledPackageKind.cask.chrome == expected)
    }
}
