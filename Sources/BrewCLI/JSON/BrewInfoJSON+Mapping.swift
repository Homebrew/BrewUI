//
//  BrewInfoJSON+Mapping.swift
//  Brew
//

import BrewCore
import Foundation

public extension BrewInfoJSON {
    func installedPackages() -> [InstalledBrewPackage] {
        let formulaPackages = formulae.map(\.asBrewPackage)
        let caskPackages = casks.map(\.asBrewPackage)
        return (formulaPackages + caskPackages).sorted(by: Self.sortByName)
    }

    private nonisolated static func sortByName(_ lhs: InstalledBrewPackage, _ rhs: InstalledBrewPackage) -> Bool {
        lhs.package.name.localizedCaseInsensitiveCompare(rhs.package.name) == .orderedAscending
    }
}

private extension BrewInfoFormula {
    var asBrewPackage: InstalledBrewPackage {
        let installedVersions = installed
            .compactMap(\.version)
            .compactMap(BrewInfoJSON.trimmedOrNil(_:))
        return InstalledBrewPackage(
            package: BrewPackage(
                name: name,
                displayName: BrewInfoJSON.trimmedOrNil(fullName) ?? name,
                kind: .formula,
                description: BrewInfoJSON.trimmedOrEmpty(desc),
                homepage: BrewInfoJSON.trimmedOrEmpty(homepage),
                latestVersion: BrewInfoJSON.trimmedOrEmpty(versions.stable),
                dependencies: HomebrewPackageID.formulaDependencies(from: dependencies),
            ),
            installedVersions: installedVersions,
            outdated: outdated,
        )
    }
}

private extension BrewInfoCask {
    var asBrewPackage: InstalledBrewPackage {
        let installed = BrewInfoJSON.uniqueNonEmpty(installedVersions)
        let latest = BrewInfoJSON.trimmedOrNil(versions.stable) ?? BrewInfoJSON.trimmedOrNil(version) ?? ""
        return InstalledBrewPackage(
            package: BrewPackage(
                name: token,
                displayName: BrewInfoJSON.trimmedOrNil(firstDisplayName) ?? token,
                kind: .cask,
                description: BrewInfoJSON.trimmedOrEmpty(desc),
                homepage: BrewInfoJSON.trimmedOrEmpty(homepage),
                latestVersion: latest,
                dependencies: HomebrewPackageID.uniqueReferences(dependencies),
            ),
            installedVersions: installed,
            outdated: outdated,
        )
    }
}

private extension BrewInfoJSON {
    nonisolated static func uniqueNonEmpty(_ values: [String]) -> [String] {
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

    nonisolated static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    nonisolated static func trimmedOrEmpty(_ value: String?) -> String {
        trimmedOrNil(value) ?? ""
    }
}
