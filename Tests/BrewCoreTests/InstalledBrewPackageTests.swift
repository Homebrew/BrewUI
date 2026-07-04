//
//  InstalledBrewPackageTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
import Foundation
import Testing

struct InstalledBrewPackageTests {
    // MARK: - isHomebrewCoreTap

    @Test func `isHomebrewCoreTap is true for homebrew core tap`() {
        let package = InstalledBrewPackage.fixture(tap: InstalledBrewPackage.homebrewCoreTapName)
        #expect(package.isHomebrewCoreTap)
    }

    @Test func `isHomebrewCoreTap is false for third-party tap`() {
        let package = InstalledBrewPackage.fixture(tap: "third-party/tap")
        #expect(!package.isHomebrewCoreTap)
    }

    @Test func `isHomebrewCoreTap is false when tap is nil`() {
        let package = InstalledBrewPackage.fixture(tap: nil)
        #expect(!package.isHomebrewCoreTap)
    }

    // MARK: - formulaSourceURL

    @Test func `formulaSourceURL resolves for homebrew core formula with rubySourcePath`() {
        let package = InstalledBrewPackage.fixture(
            name: "git",
            kind: .formula,
            tap: InstalledBrewPackage.homebrewCoreTapName,
            rubySourcePath: "Formula/g/git.rb",
        )
        #expect(
            package.formulaSourceURL?.absoluteString
                == "https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/g/git.rb",
        )
    }

    @Test func `formulaSourceURL is nil when rubySourcePath is absent`() {
        let package = InstalledBrewPackage.fixture(
            name: "git",
            kind: .formula,
            tap: InstalledBrewPackage.homebrewCoreTapName,
            rubySourcePath: nil,
        )
        #expect(package.formulaSourceURL == nil)
    }

    @Test func `formulaSourceURL is nil for casks even with rubySourcePath`() {
        let package = InstalledBrewPackage.fixture(
            name: "docker",
            kind: .cask,
            tap: InstalledBrewPackage.homebrewCoreTapName,
            rubySourcePath: "Casks/d/docker.rb",
        )
        #expect(package.formulaSourceURL == nil)
    }

    @Test func `formulaSourceURL is nil for third-party tap formulae`() {
        let package = InstalledBrewPackage.fixture(
            name: "mytool",
            kind: .formula,
            tap: "third-party/tap",
            rubySourcePath: "Formula/m/mytool.rb",
        )
        #expect(package.formulaSourceURL == nil)
    }
}
