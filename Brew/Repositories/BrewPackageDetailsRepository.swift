//
//  BrewPackageDetailsRepository.swift
//  Brew
//

import Foundation

struct BrewPackageDetailsRepository: PackageDetailsRepository {
    private let commandRunner: BrewCommandRunning
    private let locator: any BrewExecutableLocating

    init(commandRunner: BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Production wiring: real subprocess + default `brew` lookup.
    static func live() -> BrewPackageDetailsRepository {
        BrewPackageDetailsRepository(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
        )
    }

    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind? = nil
    ) async throws -> InstalledPackageDetails {
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
        if let details = mapFormula(payload: payload, packageName: name, preferredKind: preferredKind) {
            return details
        }
        if let details = mapCask(payload: payload, packageName: name, preferredKind: preferredKind) {
            return details
        }
        throw PackageDetailsRepositoryError.packageNotFound(name: name)
    }

    private func mapFormula(
        payload: BrewInfoJSON,
        packageName: String,
        preferredKind: InstalledPackageKind?,
    ) -> InstalledPackageDetails? {
        if preferredKind == .cask {
            return nil
        }
        guard let formula = payload.formulae.first(where: { $0.name == packageName }) ?? payload.formulae.first else {
            return nil
        }
        let installedVersions = formula.installed
            .compactMap(\.version)
            .map(Self.trimmedOrNil(_:))
            .compactMap(\.self)
        let dependencies = Self.uniqueNonEmpty(
            formula.dependencies +
                formula.buildDependencies +
                formula.recommendedDependencies +
                formula.optionalDependencies,
        )
        return InstalledPackageDetails(
            name: formula.name,
            kind: .formula,
            description: Self.trimmedOrNil(formula.desc),
            version: Self.trimmedOrNil(formula.versions.stable) ?? installedVersions.first,
            installedVersions: installedVersions,
            homepage: Self.trimmedOrNil(formula.homepage),
            dependencies: dependencies,
        )
    }

    private func mapCask(
        payload: BrewInfoJSON,
        packageName: String,
        preferredKind: InstalledPackageKind?,
    ) -> InstalledPackageDetails? {
        if preferredKind == .formula {
            return nil
        }
        guard let cask = payload.casks.first(where: { $0.token == packageName }) ?? payload.casks.first else {
            return nil
        }
        let installedVersions = Self.uniqueNonEmpty(cask.installedVersions)
        return InstalledPackageDetails(
            name: cask.token,
            kind: .cask,
            description: Self.trimmedOrNil(cask.desc),
            version: Self.trimmedOrNil(cask.version) ?? installedVersions.first,
            installedVersions: installedVersions,
            homepage: Self.trimmedOrNil(cask.homepage),
            dependencies: Self.uniqueNonEmpty(cask.dependencies),
        )
    }

    private static func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            guard let trimmed = trimmedOrNil(value), !seen.contains(trimmed) else {
                continue
            }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }

    private static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
