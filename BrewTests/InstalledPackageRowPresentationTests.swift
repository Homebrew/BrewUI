//
//  InstalledPackageRowPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct InstalledPackageRowPresentationTests {
    @Test func `id differs by kind for same name`() {
        let formula = InstalledPackageRow(name: "foo", kind: .formula, description: "", installedVersion: "v1")
        let cask = InstalledPackageRow(name: "foo", kind: .cask, description: "", installedVersion: "v1")
        #expect(formula.id != cask.id)
    }

    @Test func `id is stable for same kind and name`() {
        let a = InstalledPackageRow(name: "foo", kind: .formula, description: "", installedVersion: "v1")
        let b = InstalledPackageRow(name: "foo", kind: .formula, description: "x", installedVersion: "v2")
        #expect(a.id == b.id)
    }

    @Test func `hasDescription is false for empty string`() {
        let row = InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1")
        #expect(!row.hasDescription)
    }

    @Test func `hasDescription is true when description non empty`() {
        let row = InstalledPackageRow(name: "a", kind: .formula, description: "x", installedVersion: "v1")
        #expect(row.hasDescription)
    }

    @Test func `versionPresentation is installed when no update`() {
        let row = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v1",
        )
        #expect(row.versionPresentation == .installed("v1"))
    }

    @Test func `versionPresentation is upgrade when update set`() {
        let row = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        #expect(row.versionPresentation == .upgrade(current: "v1", latest: "v2"))
    }

    @Test func `showsUpdateAvailable is false when no update`() {
        let row = InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v1")
        #expect(!row.showsUpdateAvailable)
    }

    @Test func `showsUpdateAvailable is true when update set`() {
        let row = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        #expect(row.showsUpdateAvailable)
    }

    @Test func `listRowAccessibilitySummary omits description when empty`() {
        let row = InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "",
            installedVersion: "v2.0",
        )
        #expect(row.listRowAccessibilitySummary == "Git, v2.0, Installed and up to date")
    }

    @Test func `listRowAccessibilitySummary includes description when present`() {
        let row = InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "DVCS",
            installedVersion: "v2.0",
        )
        #expect(row.listRowAccessibilitySummary == "Git, DVCS, v2.0, Installed and up to date")
    }

    @Test func `listRowAccessibilitySummary appends update line when update available`() {
        let row = InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "DVCS",
            installedVersion: "v2.0",
            updateVersion: "v2.1",
        )
        #expect(row.listRowAccessibilitySummary == "Git, DVCS, v2.0, Update available to v2.1")
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
