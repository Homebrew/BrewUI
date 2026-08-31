//
//  BrewInfoJSON.swift
//  Brew
//

import BrewCore
import Foundation

/// Minimal resilient schema for `brew info --json=v2`.
public struct BrewInfoJSON: Decodable {
    var formulae: [BrewInfoFormula]
    var casks: [BrewInfoCask]

    public init(from decoder: Decoder) throws {
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
    var fullName: String?
    var tap: String?
    var desc: String?
    var license: String?
    var homepage: String?
    var dependencies: [String]
    var rubySourcePath: String?
    var versions: BrewInfoFormulaVersions
    /// Homebrew packaging revision; part of the keg version as `_<revision>` once non-zero.
    var revision: Int
    var installed: [BrewInfoFormulaInstalled]
    var linkedKeg: String?
    var pinned: Bool
    var kegOnly: Bool
    var caveats: String?
    var outdated: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        fullName = try? container.decode(String.self, forKey: .fullName)
        tap = try? container.decode(String.self, forKey: .tap)
        desc = try? container.decode(String.self, forKey: .desc)
        license = try? container.decode(String.self, forKey: .license)
        homepage = try? container.decode(String.self, forKey: .homepage)
        dependencies = container.decodeStringArray(forKey: .dependencies)
        rubySourcePath = try? container.decode(String.self, forKey: .rubySourcePath)
        versions = (try? container.decode(BrewInfoFormulaVersions.self, forKey: .versions))
            ?? BrewInfoFormulaVersions(stable: nil)
        revision = (try? container.decode(Int.self, forKey: .revision)) ?? 0
        installed = (try? container.decode([BrewInfoFormulaInstalled].self, forKey: .installed))
            ?? []
        linkedKeg = try? container.decode(String.self, forKey: .linkedKeg)
        pinned = (try? container.decode(Bool.self, forKey: .pinned)) ?? false
        kegOnly = (try? container.decode(Bool.self, forKey: .kegOnly)) ?? false
        caveats = try? container.decode(String.self, forKey: .caveats)
        outdated = (try? container.decode(Bool.self, forKey: .outdated)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case tap
        case desc
        case license
        case homepage
        case dependencies
        case rubySourcePath = "ruby_source_path"
        case versions
        case revision
        case installed
        case linkedKeg = "linked_keg"
        case pinned
        case kegOnly = "keg_only"
        case caveats
        case outdated
    }
}

struct BrewInfoFormulaVersions: Decodable {
    var stable: String?
}

struct BrewInfoFormulaInstalled: Decodable {
    var version: String?
    var installedOnRequest: Bool
    var pouredFromBottle: Bool
    var time: TimeInterval?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try? container.decode(String.self, forKey: .version)
        installedOnRequest = (try? container.decode(Bool.self, forKey: .installedOnRequest)) ?? true
        pouredFromBottle = (try? container.decode(Bool.self, forKey: .pouredFromBottle)) ?? false
        time = try? container.decode(TimeInterval.self, forKey: .time)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case installedOnRequest = "installed_on_request"
        case pouredFromBottle = "poured_from_bottle"
        case time
    }
}

struct BrewInfoCask: Decodable {
    var token: String
    var tap: String?
    var names: [String]
    var desc: String?
    var homepage: String?
    /// Tap / current cask version string (upgrade target analogue to formula `versions.stable`).
    var version: String?
    /// Nested stable when present in JSON (current Homebrew `--json=v2` casks omit this; formulae-style mirror).
    var versions: BrewInfoFormulaVersions
    var installedVersions: [String]
    var installedOnRequest: Bool
    var dependencies: [HomebrewPackageID]
    var outdated: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = (try? container.decode(String.self, forKey: .token)) ?? ""
        tap = try? container.decode(String.self, forKey: .tap)
        names = container.decodeStringArrayOrSingle(forKey: .name)
        desc = try? container.decode(String.self, forKey: .desc)
        homepage = try? container.decode(String.self, forKey: .homepage)
        version = try? container.decode(String.self, forKey: .version)
        versions = (try? container.decode(BrewInfoFormulaVersions.self, forKey: .versions))
            ?? BrewInfoFormulaVersions(stable: nil)
        installedVersions = container.decodeInstalledVersions(forKey: .installed)
        installedOnRequest = (try? container.decode(Bool.self, forKey: .installedOnRequest)) ?? true
        dependencies = container.decodeCaskDependencyReferences(
            forKeys: [.dependencies, .dependsOn],
        )
        outdated = (try? container.decode(Bool.self, forKey: .outdated)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case tap
        case name
        case desc
        case homepage
        case version
        case versions
        case installed
        case installedOnRequest = "installed_on_request"
        case dependencies
        case dependsOn = "depends_on"
        case outdated
    }

    var firstDisplayName: String? {
        names.first
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

    func decodeStringArrayOrSingle(forKey key: Key) -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values.filter { !$0.isEmpty }
        }
        if let value = try? decode(String.self, forKey: key), !value.isEmpty {
            return [value]
        }
        return []
    }

    func decodeCaskDependencyReferences(forKeys keys: [Key]) -> [HomebrewPackageID] {
        for key in keys {
            let references = decodeCaskDependencyReferences(forKey: key)
            if !references.isEmpty {
                return references
            }
        }
        return []
    }

    func decodeCaskDependencyReferences(forKey key: Key) -> [HomebrewPackageID] {
        if let array = try? decode([String].self, forKey: key) {
            return HomebrewPackageID.formulaDependencies(from: array)
        }
        if let single = try? decode(String.self, forKey: key), !single.isEmpty {
            return HomebrewPackageID.formulaDependencies(from: [single])
        }
        guard let nested = try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) else {
            return []
        }

        var merged: [HomebrewPackageID] = []
        for nestedKey in nested.allKeys {
            switch nestedKey.stringValue {
            case "formula":
                merged.append(
                    contentsOf: HomebrewPackageID.formulaDependencies(
                        from: nested.decodeStringArray(forKey: nestedKey),
                    ),
                )
            case "cask":
                let caskTokens = nested.decodeStringArray(forKey: nestedKey)
                merged.append(contentsOf: caskTokens.map { HomebrewPackageID.cask(token: $0) })
            default:
                continue
            }
        }
        return HomebrewPackageID.uniqueReferences(merged)
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
