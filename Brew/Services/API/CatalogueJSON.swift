//
//  CatalogueJSON.swift
//  Brew
//

import Foundation

nonisolated struct FormulaCatalogueJSON: Codable {
    let items: [FormulaCatalogueItemJSON]
    let decodeFailures: [CatalogueItemDecodeFailure]

    init(from decoder: Decoder) throws {
        (items, decodeFailures) = try decodeCatalogueItems(from: decoder, as: FormulaCatalogueItemJSON.self)
    }
}

nonisolated struct CaskCatalogueJSON: Codable {
    let items: [CaskCatalogueItemJSON]
    let decodeFailures: [CatalogueItemDecodeFailure]

    init(from decoder: Decoder) throws {
        (items, decodeFailures) = try decodeCatalogueItems(from: decoder, as: CaskCatalogueItemJSON.self)
    }
}

nonisolated struct CatalogueItemDecodeFailure: Codable, Equatable {
    let index: Int
    let underlying: String
}

nonisolated struct FormulaCatalogueItemJSON: Codable {
    let name: String
    let desc: String
    let homepage: String
    let versions: CatalogueVersionsJSON
    let dependencies: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        desc = try container.decode(String.self, forKey: .desc)
        homepage = try container.decode(String.self, forKey: .homepage)
        versions = try container.decode(CatalogueVersionsJSON.self, forKey: .versions)
        dependencies = container.decodeStringArray(forKey: .dependencies)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case desc
        case homepage
        case versions
        case dependencies
    }
}

nonisolated struct CaskCatalogueItemJSON: Codable {
    /// Cask token used for package identity and Discover catalogue joins.
    let name: String
    let displayName: String
    let desc: String
    let homepage: String
    let stableVersion: String
    let dependencies: [String]
    let dependsOn: CatalogueDependsOnJSON?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireNames = Self.decodeWireNames(from: container)
        if let token = try container.decodeIfPresent(String.self, forKey: .token) {
            name = token
            displayName = wireNames.first ?? token
        } else if let wireName = wireNames.first {
            name = wireName
            displayName = wireName
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.token,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected cask token or name.",
                ),
            )
        }

        desc = try (container.decodeIfPresent(String.self, forKey: .desc)) ?? ""
        homepage = try (container.decodeIfPresent(String.self, forKey: .homepage)) ?? ""

        if let versions = try container.decodeIfPresent(CatalogueVersionsJSON.self, forKey: .versions) {
            stableVersion = versions.stable
        } else if let version = try container.decodeIfPresent(String.self, forKey: .version) {
            stableVersion = version
        } else {
            stableVersion = ""
        }

        dependencies = container.decodeStringArray(forKey: .dependencies)
        dependsOn = try? container.decode(CatalogueDependsOnJSON.self, forKey: .dependsOn)
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case name
        case desc
        case homepage
        case version
        case versions
        case dependencies
        case dependsOn = "depends_on"
    }

    private static func decodeWireNames(from container: KeyedDecodingContainer<CodingKeys>) -> [String] {
        if let names = try? container.decode([String].self, forKey: .name) {
            return names.compactMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        if let name = try? container.decode(String.self, forKey: .name) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .token)
        try container.encode([displayName], forKey: .name)
        try container.encode(desc, forKey: .desc)
        try container.encode(homepage, forKey: .homepage)
        if stableVersion.isEmpty {
            try container.encode(CatalogueVersionsJSON(stable: ""), forKey: .versions)
        } else {
            try container.encode(stableVersion, forKey: .version)
        }
        try container.encode(dependencies, forKey: .dependencies)
        try container.encodeIfPresent(dependsOn, forKey: .dependsOn)
    }
}

nonisolated struct CatalogueVersionsJSON: Codable {
    let stable: String
}

nonisolated struct CatalogueDependsOnJSON: Codable {
    let formula: [String]
    let cask: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formula = container.decodeStringArray(forKey: .formula)
        cask = container.decodeStringArray(forKey: .cask)
    }

    private enum CodingKeys: String, CodingKey {
        case formula
        case cask
    }
}

extension FormulaCatalogueItemJSON {
    var description: String {
        desc
    }

    var stableVersion: String {
        versions.stable
    }

    var dependencyReferences: [HomebrewPackageReference] {
        HomebrewPackageReference.formulaDependencies(from: dependencies)
    }
}

extension CaskCatalogueItemJSON {
    var description: String {
        desc
    }

    var dependencyReferences: [HomebrewPackageReference] {
        let formulaDependencies = HomebrewPackageReference.formulaDependencies(
            from: dependencies + (dependsOn?.formula ?? []),
        )
        let caskDependencies = (dependsOn?.cask ?? []).compactMap { token -> HomebrewPackageReference? in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : .cask(token: trimmed)
        }
        return HomebrewPackageReference.uniqueReferences(formulaDependencies + caskDependencies)
    }
}

private nonisolated func decodeCatalogueItems<Item: Decodable>(
    from decoder: Decoder,
    as _: Item.Type,
) throws -> ([Item], [CatalogueItemDecodeFailure]) {
    var container = try decoder.unkeyedContainer()
    var decodedItems: [Item] = []
    var failures: [CatalogueItemDecodeFailure] = []
    decodedItems.reserveCapacity(container.count ?? 0)

    while !container.isAtEnd {
        let index = container.currentIndex
        let itemDecoder = try container.superDecoder()
        do {
            let item = try Item(from: itemDecoder)
            decodedItems.append(item)
        } catch {
            failures.append(
                CatalogueItemDecodeFailure(
                    index: index,
                    underlying: String(describing: error),
                ),
            )
        }
    }

    return (decodedItems, failures)
}

private extension KeyedDecodingContainer {
    func decodeStringArray(forKey key: Key) -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values.compactMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        if let value = try? decode(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return []
    }
}
