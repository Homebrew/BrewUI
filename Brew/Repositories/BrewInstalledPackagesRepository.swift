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
        let output = try await runInstalledInfoJSON(executable: brew)
        let payload = try decodeInfoJSON(from: output)
        return InstalledPackagesSnapshot(
            formulae: payload.formulae.map(Self.formulaInfo).sorted(by: Self.sortByName),
            casks: payload.casks.map(Self.caskInfo).sorted(by: Self.sortByName),
        )
    }

    private func runInstalledInfoJSON(executable: URL) async throws -> String {
        let arguments = ["info", "--installed", "--json=v2"]
        let output = try await commandRunner.run(executableURL: executable, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        return output.standardOutput
    }

    private func decodeInfoJSON(from standardOutput: String) throws -> BrewInfoJSON {
        let data = Data(standardOutput.utf8)
        do {
            return try JSONDecoder().decode(BrewInfoJSON.self, from: data)
        } catch {
            throw BrewCommandError.launchFailed(
                underlying: String(
                    localized: "Failed to decode Homebrew JSON output.",
                    comment: "Installed tab JSON decode failure",
                ),
            )
        }
    }

    private static func formulaInfo(from formula: BrewInfoFormula) -> InstalledPackageInfo {
        InstalledPackageInfo(
            name: formula.name,
            version: formula.installed
                .compactMap(\.version)
                .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                ?? formula.versions.stable,
        )
    }

    private static func caskInfo(from cask: BrewInfoCask) -> InstalledPackageInfo {
        InstalledPackageInfo(
            name: cask.token,
            version: cask.installedVersions.first ?? cask.version,
        )
    }

    private static func sortByName(_ lhs: InstalledPackageInfo, _ rhs: InstalledPackageInfo) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
