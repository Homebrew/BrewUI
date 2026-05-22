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
    let versions: Versions
    let dependencies: [String]

    nonisolated struct Versions: Codable {
        let stable: String
    }
}

nonisolated struct CaskCatalogueItemJSON: Codable {
    let token: String
    let names: [String]
    let desc: String?
    let homepage: String
    let version: String
    let dependsOn: DependsOn

    private enum CodingKeys: String, CodingKey {
        case token
        case names = "name"
        case desc
        case homepage
        case version
        case dependsOn = "depends_on"
    }

    nonisolated struct DependsOn: Codable {
        var formula: [String]
        var cask: [String]

        init(formula: [String] = [], cask: [String] = []) {
            self.formula = formula
            self.cask = cask
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formula = try container.decodeIfPresent([String].self, forKey: .formula) ?? []
            cask = try container.decodeIfPresent([String].self, forKey: .cask) ?? []
        }
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

    var dependencyReferences: [HomebrewPackageReference] {
        let formulaDependencies = HomebrewPackageReference.formulaDependencies(from: dependsOn.formula)
        let caskDependencies = dependsOn.cask.map { HomebrewPackageReference.cask(token: $0) }
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
