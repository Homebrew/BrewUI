//
//  BrewCommandsTests.swift
//  BrewCoreTests
//

@testable import BrewCore
import Foundation
import Testing

struct BrewCommandsTests {
    @Test func `install builds formula argv and kind`() {
        let command = BrewCommands.install("git", kind: .formula)
        #expect(command.arguments == ["install", "--formula", "git"])
        #expect(command.operationKind == .installFormula)
    }

    @Test func `install builds cask argv and kind`() {
        let command = BrewCommands.install("docker", kind: .cask)
        #expect(command.arguments == ["install", "--cask", "docker"])
        #expect(command.operationKind == .installCask)
    }

    @Test func `upgrade builds argv and kind per kind`() {
        #expect(BrewCommands.upgrade("git", kind: .formula).arguments == ["upgrade", "--formula", "git"])
        #expect(BrewCommands.upgrade("git", kind: .formula).operationKind == .upgradeFormula)
        #expect(BrewCommands.upgrade("docker", kind: .cask).operationKind == .upgradeCask)
    }

    @Test func `uninstall builds argv and kind per kind`() {
        #expect(BrewCommands.uninstall("git", kind: .formula).arguments == ["uninstall", "--formula", "git"])
        #expect(BrewCommands.uninstall("git", kind: .formula).operationKind == .uninstallFormula)
        #expect(BrewCommands.uninstall("docker", kind: .cask).operationKind == .uninstallCask)
    }

    @Test func `bulkUpgrade carries the selection argv under upgradeAll`() {
        let selection = BrewUpgradeSelection.explicit(["git", "slack"])
        let command = BrewCommands.bulkUpgrade(selection)
        #expect(command.arguments == selection.arguments)
        #expect(command.operationKind == .upgradeAll)
    }

    @Test func `doctorFix passes the argv through under doctorFix`() {
        let command = BrewCommands.doctorFix(arguments: ["link", "openssl@3"])
        #expect(command.arguments == ["link", "openssl@3"])
        #expect(command.operationKind == .doctorFix)
    }

    @Test func `doctorRead runs brew doctor under doctorRead`() {
        let command = BrewCommands.doctorRead()
        #expect(command.arguments == ["doctor"])
        #expect(command.operationKind == .doctorRead)
    }
}
