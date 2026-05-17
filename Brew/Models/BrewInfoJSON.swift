//
//  BrewInfoJSON.swift
//  Brew
//

import Foundation

/// Minimal resilient schema for `brew info --json=v2`.
struct BrewInfoJSON: Decodable {
    var formulae: [BrewInfoFormula]
    var casks: [BrewInfoCask]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formulae = (try? container.decode([BrewInfoFormula].self, forKey: .formulae)) ?? []
        casks = (try? container.decode([BrewInfoCask].self, forKey: .casks)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case formulae
        case casks
    }
}

struct BrewInfoFormula: Decodable {
    var name: String
    var desc: String?
    var homepage: String?
    var dependencies: [String]
    var buildDependencies: [String]
    var recommendedDependencies: [String]
    var optionalDependencies: [String]
    var versions: BrewInfoFormulaVersions
    var installed: [BrewInfoFormulaInstalled]
    var outdated: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        desc = try? container.decode(String.self, forKey: .desc)
        homepage = try? container.decode(String.self, forKey: .homepage)
        dependencies = container.decodeStringArray(forKey: .dependencies)
        buildDependencies = container.decodeStringArray(forKey: .buildDependencies)
        recommendedDependencies = container.decodeStringArray(forKey: .recommendedDependencies)
        optionalDependencies = container.decodeStringArray(forKey: .optionalDependencies)
        versions = (try? container.decode(BrewInfoFormulaVersions.self, forKey: .versions))
            ?? BrewInfoFormulaVersions(stable: nil)
        installed = (try? container.decode([BrewInfoFormulaInstalled].self, forKey: .installed))
            ?? []
        outdated = (try? container.decode(Bool.self, forKey: .outdated)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case desc
        case homepage
        case dependencies
        case buildDependencies = "build_dependencies"
        case recommendedDependencies = "recommended_dependencies"
        case optionalDependencies = "optional_dependencies"
        case versions
        case installed
        case outdated
    }
}

struct BrewInfoFormulaVersions: Decodable {
    var stable: String?
}

struct BrewInfoFormulaInstalled: Decodable {
    var version: String?
}

struct BrewInfoCask: Decodable {
    var token: String
    var desc: String?
    var homepage: String?
    /// Tap / current cask version string (upgrade target analogue to formula `versions.stable`).
    var version: String?
    /// Nested stable when present in JSON (current Homebrew `--json=v2` casks omit this; formulae-style mirror).
    var versions: BrewInfoFormulaVersions
    var installedVersions: [String]
    var dependencies: [HomebrewPackageReference]
    var outdated: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = (try? container.decode(String.self, forKey: .token)) ?? ""
        desc = try? container.decode(String.self, forKey: .desc)
        homepage = try? container.decode(String.self, forKey: .homepage)
        version = try? container.decode(String.self, forKey: .version)
        versions = (try? container.decode(BrewInfoFormulaVersions.self, forKey: .versions))
            ?? BrewInfoFormulaVersions(stable: nil)
        installedVersions = container.decodeInstalledVersions(forKey: .installed)
        dependencies = container.decodeCaskDependencyReferences(
            forKeys: [.dependencies, .dependsOn],
        )
        outdated = (try? container.decode(Bool.self, forKey: .outdated)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case desc
        case homepage
        case version
        case versions
        case installed
        case dependencies
        case dependsOn = "depends_on"
        case outdated
    }
}

private extension KeyedDecodingContainer {
    func decodeStringArray(forKey key: Key) -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values
        }
        if let value = try? decode(String.self, forKey: key), !value.isEmpty {
            return [value]
        }
        return []
    }

    func decodeInstalledVersions(forKey key: Key) -> [String] {
        if let value = try? decode(String.self, forKey: key), !value.isEmpty {
            return [value]
        }
        if let values = try? decode([String].self, forKey: key) {
            return values.filter { !$0.isEmpty }
        }
        return []
    }

    func decodeCaskDependencyReferences(forKeys keys: [Key]) -> [HomebrewPackageReference] {
        for key in keys {
            let references = decodeCaskDependencyReferences(forKey: key)
            if !references.isEmpty {
                return references
            }
        }
        return []
    }

    func decodeCaskDependencyReferences(forKey key: Key) -> [HomebrewPackageReference] {
        if let array = try? decode([String].self, forKey: key) {
            return HomebrewPackageReference.formulaDependencies(from: array)
        }
        if let single = try? decode(String.self, forKey: key), !single.isEmpty {
            return HomebrewPackageReference.formulaDependencies(from: [single])
        }
        guard let nested = try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) else {
            return []
        }

        var merged: [HomebrewPackageReference] = []
        for nestedKey in nested.allKeys {
            switch nestedKey.stringValue {
            case "formula":
                merged.append(
                    contentsOf: HomebrewPackageReference.formulaDependencies(
                        from: nested.decodeStringArray(forKey: nestedKey),
                    ),
                )
            case "cask":
                let caskTokens = nested.decodeStringArray(forKey: nestedKey)
                merged.append(contentsOf: caskTokens.map { HomebrewPackageReference.cask(token: $0) })
            default:
                continue
            }
        }
        return HomebrewPackageReference.uniqueReferences(merged)
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
