//
//  CatalogueJSON.swift
//  BrewNetworking
//

import BrewCore
import Foundation

public struct FormulaCatalogueJSON: Codable, Sendable {
    public let items: [FormulaCatalogueItemJSON]
    public let decodeFailures: [CatalogueItemDecodeFailure]

    public init(from decoder: Decoder) throws {
        (items, decodeFailures) = try decodeCatalogueItems(from: decoder, as: FormulaCatalogueItemJSON.self)
    }
}

public struct CaskCatalogueJSON: Codable, Sendable {
    public let items: [CaskCatalogueItemJSON]
    public let decodeFailures: [CatalogueItemDecodeFailure]

    public init(from decoder: Decoder) throws {
        (items, decodeFailures) = try decodeCatalogueItems(from: decoder, as: CaskCatalogueItemJSON.self)
    }
}

public struct CatalogueItemDecodeFailure: Codable, Equatable, Sendable {
    public let index: Int
    public let underlying: String
}

public struct FormulaCatalogueItemJSON: Codable, Sendable {
    public let name: String
    public let desc: String
    public let homepage: String
    public let versions: Versions
    public let revision: Int?
    public let dependencies: [String]

    public struct Versions: Codable, Sendable {
        public let stable: String
    }
}

public struct CaskCatalogueItemJSON: Codable, Sendable {
    public let token: String
    public let names: [String]
    public let desc: String?
    public let homepage: String
    public let version: String
    public let dependsOn: DependsOn

    private enum CodingKeys: String, CodingKey {
        case token
        case names = "name"
        case desc
        case homepage
        case version
        case dependsOn = "depends_on"
    }

    public struct DependsOn: Codable, Sendable {
        public var formula: [String]
        public var cask: [String]

        public init(formula: [String] = [], cask: [String] = []) {
            self.formula = formula
            self.cask = cask
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formula = try container.decodeIfPresent([String].self, forKey: .formula) ?? []
            cask = try container.decodeIfPresent([String].self, forKey: .cask) ?? []
        }
    }
}

public extension FormulaCatalogueItemJSON {
    var description: String {
        desc
    }

    var stableVersion: String {
        HomebrewPkgVersion.string(version: versions.stable, revision: revision) ?? versions.stable
    }

    var dependencyReferences: [HomebrewPackageID] {
        HomebrewPackageID.formulaDependencies(from: dependencies)
    }
}

public extension CaskCatalogueItemJSON {
    var name: String {
        token
    }

    var displayName: String {
        names.first ?? token
    }

    var description: String? {
        desc
    }

    var stableVersion: String {
        version
    }

    var dependencyReferences: [HomebrewPackageID] {
        let formulaDependencies = HomebrewPackageID.formulaDependencies(from: dependsOn.formula)
        let caskDependencies = dependsOn.cask.map { HomebrewPackageID.cask(token: $0) }
        return HomebrewPackageID.uniqueReferences(formulaDependencies + caskDependencies)
    }
}

private func decodeCatalogueItems<Item: Decodable>(
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
