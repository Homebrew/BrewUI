//
//  BrewCommandsPinTests.swift
//  BrewCoreTests
//

@testable import BrewCore
import Foundation
import Testing

struct BrewCommandsPinTests {
    @Test func `pin builds formula argv and kind`() {
        let command = BrewCommands.pin("wget", kind: .formula)
        #expect(command.arguments == ["pin", "--formula", "wget"])
        #expect(command.operationKind == .pinFormula)
    }

    @Test func `pin builds cask argv and kind`() {
        let command = BrewCommands.pin("docker", kind: .cask)
        #expect(command.arguments == ["pin", "--cask", "docker"])
        #expect(command.operationKind == .pinCask)
    }

    @Test func `unpin builds formula argv and kind`() {
        let command = BrewCommands.unpin("wget", kind: .formula)
        #expect(command.arguments == ["unpin", "--formula", "wget"])
        #expect(command.operationKind == .unpinFormula)
    }

    @Test func `unpin builds cask argv and kind`() {
        let command = BrewCommands.unpin("docker", kind: .cask)
        #expect(command.arguments == ["unpin", "--cask", "docker"])
        #expect(command.operationKind == .unpinCask)
    }
}
