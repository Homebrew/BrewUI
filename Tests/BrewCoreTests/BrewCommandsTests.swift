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

    @Test func `install requires a bottle for formulae when requested`() {
        #expect(BrewCommands.install("git", kind: .formula, forceBottle: true).arguments == [
            "install", "--formula", "--force-bottle", "git",
        ])
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

    @Test func `upgrade requires bottles for formulae but not casks`() {
        #expect(BrewCommands.upgrade("git", kind: .formula, forceBottle: true).arguments == [
            "upgrade", "--formula", "--force-bottle", "git",
        ])
        #expect(BrewCommands.upgrade("docker", kind: .cask, forceBottle: true).arguments == [
            "upgrade", "--cask", "docker",
        ])
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

    @Test func `bulkUpgrade requires bottles for formulae but not casks`() {
        #expect(BrewCommands.bulkUpgrade(.formulae, forceBottle: true).arguments == [
            "upgrade", "--formula", "--force-bottle",
        ])
        #expect(BrewCommands.bulkUpgrade(.casks, forceBottle: true).arguments == ["upgrade", "--cask"])
        #expect(BrewCommands.bulkUpgrade(.all, forceBottle: true).arguments == ["upgrade", "--force-bottle"])
    }

    @Test func `selfUpgrade upgrades the app's own cask under upgradeApp`() {
        let command = BrewCommands.selfUpgrade()
        #expect(command.arguments == ["upgrade", "--cask", "homebrew-app"])
        #expect(command.arguments == ["upgrade", "--cask", SelfUpgradeIdentity.caskToken])
        #expect(command.operationKind == .upgradeApp)
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
