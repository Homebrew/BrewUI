//
//  BrewInfoJSON.swift
//  Brew
//

import Foundation

/// Minimal resilient schema for `brew info --json=v2`.
struct BrewInfoJSON: Decodable {
    var formulae: [Formula]
    var casks: [Cask]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formulae = (try? container.decode([Formula].self, forKey: .formulae)) ?? []
        casks = (try? container.decode([Cask].self, forKey: .casks)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case formulae
        case casks
    }
}

extension BrewInfoJSON {
    struct Formula: Decodable {
        var name: String
        var desc: String?
        var homepage: String?
        var dependencies: [String]
        var buildDependencies: [String]
        var recommendedDependencies: [String]
        var optionalDependencies: [String]
        var versions: Versions
        var installed: [Installed]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? container.decode(String.self, forKey: .name)) ?? ""
            desc = try? container.decode(String.self, forKey: .desc)
            homepage = try? container.decode(String.self, forKey: .homepage)
            dependencies = container.decodeStringArray(forKey: .dependencies)
            buildDependencies = container.decodeStringArray(forKey: .buildDependencies)
            recommendedDependencies = container.decodeStringArray(forKey: .recommendedDependencies)
            optionalDependencies = container.decodeStringArray(forKey: .optionalDependencies)
            versions = (try? container.decode(Versions.self, forKey: .versions)) ?? Versions(stable: nil)
            installed = (try? container.decode([Installed].self, forKey: .installed)) ?? []
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
        }
    }

    struct Versions: Decodable {
        var stable: String?
    }

    struct Installed: Decodable {
        var version: String?
    }
}

extension BrewInfoJSON {
    struct Cask: Decodable {
        var token: String
        var desc: String?
        var homepage: String?
        var version: String?
        var installedVersions: [String]
        var dependencies: [String]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            token = (try? container.decode(String.self, forKey: .token)) ?? ""
            desc = try? container.decode(String.self, forKey: .desc)
            homepage = try? container.decode(String.self, forKey: .homepage)
            version = try? container.decode(String.self, forKey: .version)
            installedVersions = container.decodeInstalledVersions(forKey: .installed)
            dependencies = container.decodeCaskDependencies(forKey: .dependencies)
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case desc
            case homepage
            case version
            case installed
            case dependencies
        }
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

    func decodeCaskDependencies(forKey key: Key) -> [String] {
        if let array = try? decode([String].self, forKey: key) {
            return array
        }
        if let single = try? decode(String.self, forKey: key), !single.isEmpty {
            return [single]
        }
        guard let nested = try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) else {
            return []
        }

        var merged: [String] = []
        for nestedKey in nested.allKeys {
            let values = nested.decodeStringArray(forKey: nestedKey)
            merged.append(contentsOf: values)
        }
        return merged
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
