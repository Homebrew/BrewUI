//
//  BrewPackageDetailsRepository.swift
//  Brew
//

import Foundation

struct BrewPackageDetailsRepository: PackageDetailsRepository {
    private let commandRunner: BrewCommandRunning
    private let locator: any BrewExecutableLocating

    nonisolated init(commandRunner: BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Production wiring: real subprocess + default `brew` lookup.
    nonisolated static func live() -> BrewPackageDetailsRepository {
        BrewPackageDetailsRepository(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
        )
    }

    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind? = nil,
    ) async throws -> BrewPackage {
        let brew = try locator.findBrewExecutable()
        let arguments = ["info", name, "--json=v2"]
        let output = try await commandRunner.run(executableURL: brew, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }

        guard let data = output.standardOutput.data(using: .utf8) else {
            throw PackageDetailsRepositoryError.invalidJSONOutput
        }

        let payload = try JSONDecoder().decode(BrewInfoJSON.self, from: data)
        if let details = payload.packageDetails(named: name, preferredKind: preferredKind) {
            return details
        }
        throw PackageDetailsRepositoryError.packageNotFound(name: name)
    }
}
