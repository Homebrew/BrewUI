//
//  InstalledPackagesParserTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct InstalledPackagesParserTests {
    @Test func `parses names and versions`() {
        let out = """
        zsh 5.9
        git 2.45.0
        openssl@3 3.4.0
        """
        let rows = InstalledPackagesParser.parseListVersionsOutput(out)
        #expect(rows.count == 3)
        #expect(rows[0].name == "git")
        #expect(rows[0].version == "2.45.0")
        #expect(rows[1].name == "openssl@3")
        #expect(rows[1].version == "3.4.0")
        #expect(rows[2].name == "zsh")
    }

    @Test func `name only line has nil version`() {
        let rows = InstalledPackagesParser.parseListVersionsOutput("wget\n")
        #expect(rows.count == 1)
        #expect(rows[0].name == "wget")
        #expect(rows[0].version == nil)
    }

    @Test func `skips empty lines`() {
        let rows = InstalledPackagesParser.parseListVersionsOutput("\n\na 1\n\n")
        #expect(rows.count == 1)
    }

    @Test func `sorts case insensitive`() {
        let out = """
        Beta 2
        alpha 1
        """
        let rows = InstalledPackagesParser.parseListVersionsOutput(out)
        #expect(rows.map(\.name) == ["alpha", "Beta"])
    }
}
