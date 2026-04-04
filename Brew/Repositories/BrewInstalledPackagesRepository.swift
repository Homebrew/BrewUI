//
//  BrewInstalledPackagesRepository.swift
//  Brew
//

import Foundation

struct BrewInstalledPackagesRepository: InstalledPackagesRepository {
    private let commandRunner: BrewCommandRunning
    private let locator: any BrewExecutableLocating

    init(commandRunner: BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Production wiring: real subprocess + default `brew` lookup.
    static func live() -> BrewInstalledPackagesRepository {
        BrewInstalledPackagesRepository(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
        )
    }

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        let brew = try locator.findBrewExecutable()
        let formulaOutput = try await runListVersions(executable: brew, cask: false)
        let caskOutput = try await runListVersions(executable: brew, cask: true)
        return InstalledPackagesSnapshot(
            formulae: InstalledPackagesParser.parseListVersionsOutput(formulaOutput),
            casks: InstalledPackagesParser.parseListVersionsOutput(caskOutput),
        )
    }

    private func runListVersions(executable: URL, cask: Bool) async throws -> String {
        var arguments = ["list", "--versions"]
        arguments.append(cask ? "--cask" : "--formula")
        let output = try await commandRunner.run(executableURL: executable, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        return output.standardOutput
    }
}
