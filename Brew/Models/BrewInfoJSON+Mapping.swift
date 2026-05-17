//
//  BrewInfoJSON+Mapping.swift
//  Brew
//

import Foundation

extension BrewInfoJSON {
    func installedPackages() -> [BrewPackage] {
        let formulaPackages = formulae.map(\.asBrewPackage)
        let caskPackages = casks.map(\.asBrewPackage)
        return (formulaPackages + caskPackages).sorted(by: Self.sortByName)
    }

    private nonisolated static func sortByName(_ lhs: BrewPackage, _ rhs: BrewPackage) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private extension BrewInfoFormula {
    var asBrewPackage: BrewPackage {
        let installedVersions = installed
            .compactMap(\.version)
            .compactMap(BrewInfoJSON.trimmedOrNil(_:))
        let runtimeDependencies = dependencies
        return BrewPackage(
            name: name,
            kind: .formula,
            description: BrewInfoJSON.trimmedOrEmpty(desc),
            homepage: BrewInfoJSON.trimmedOrEmpty(homepage),
            latestVersion: BrewInfoJSON.trimmedOrEmpty(versions.stable),
            installedVersions: installedVersions,
            dependencies: HomebrewPackageReference.formulaDependencies(from: runtimeDependencies),
            outdated: outdated,
        )
    }
}

private extension BrewInfoCask {
    var asBrewPackage: BrewPackage {
        let installed = BrewInfoJSON.uniqueNonEmpty(installedVersions)
        let latest = BrewInfoJSON.trimmedOrNil(versions.stable) ?? BrewInfoJSON.trimmedOrNil(version) ?? ""
        return BrewPackage(
            name: token,
            kind: .cask,
            description: BrewInfoJSON.trimmedOrEmpty(desc),
            homepage: BrewInfoJSON.trimmedOrEmpty(homepage),
            latestVersion: latest,
            installedVersions: installed,
            dependencies: HomebrewPackageReference.uniqueReferences(dependencies),
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
