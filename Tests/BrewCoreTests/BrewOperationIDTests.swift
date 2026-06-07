//
//  BrewOperationIDTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct BrewOperationIDTests {
    @Test func `package init builds a package id exposing its package identity`() {
        let id = BrewOperationID(packageID: .formula(name: "git"))
        #expect(id == .package(.formula(name: "git")))
        #expect(id.packageID == .formula(name: "git"))
    }

    @Test func `kind and name init builds the matching package case`() {
        #expect(BrewOperationID(kind: .formula, name: "git") == .package(.formula(name: "git")))
        #expect(BrewOperationID(kind: .cask, name: "firefox") == .package(.cask(token: "firefox")))
    }

    @Test func `maintenance init carries token and display command`() {
        let id = BrewOperationID(maintenanceToken: "link:openssl@3", displayCommand: "brew link openssl@3")
        #expect(id == .maintenance(token: "link:openssl@3", displayCommand: "brew link openssl@3"))
    }

    @Test func `maintenance id has no package identity`() {
        let id = BrewOperationID(maintenanceToken: "cleanup", displayCommand: "brew cleanup")
        #expect(id.packageID == nil)
    }

    @Test func `maintenance ids differ by token even with the same display command`() {
        let first = BrewOperationID(maintenanceToken: "a", displayCommand: "brew doctor")
        let second = BrewOperationID(maintenanceToken: "b", displayCommand: "brew doctor")
        #expect(first != second)
    }

    @Test func `package and maintenance ids are distinct`() {
        let package = BrewOperationID(kind: .formula, name: "cleanup")
        let maintenance = BrewOperationID(maintenanceToken: "cleanup", displayCommand: "brew cleanup")
        #expect(package != maintenance)
    }
}
