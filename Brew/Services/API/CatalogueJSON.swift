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
    let analytics: CatalogueAnalyticsJSON
    let dependencies: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        desc = try container.decode(String.self, forKey: .desc)
        homepage = try container.decode(String.self, forKey: .homepage)
        versions = try container.decode(CatalogueVersionsJSON.self, forKey: .versions)
        analytics = try container.decode(CatalogueAnalyticsJSON.self, forKey: .analytics)
        dependencies = container.decodeStringArray(forKey: .dependencies)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case desc
        case homepage
        case versions
        case analytics
        case dependencies
    }
}

nonisolated struct CaskCatalogueItemJSON: Codable {
    let name: String
    let desc: String
    let homepage: String
    let versions: CatalogueVersionsJSON
    let analytics: CatalogueAnalyticsJSON
    let dependencies: [String]
    let dependsOn: CatalogueDependsOnJSON?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        desc = try container.decode(String.self, forKey: .desc)
        homepage = try container.decode(String.self, forKey: .homepage)
        versions = try container.decode(CatalogueVersionsJSON.self, forKey: .versions)
        analytics = try container.decode(CatalogueAnalyticsJSON.self, forKey: .analytics)
        dependencies = container.decodeStringArray(forKey: .dependencies)
        dependsOn = try? container.decode(CatalogueDependsOnJSON.self, forKey: .dependsOn)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case desc
        case homepage
        case versions
        case analytics
        case dependencies
        case dependsOn = "depends_on"
    }
}

nonisolated struct CatalogueVersionsJSON: Codable {
    let stable: String
}

nonisolated struct CatalogueAnalyticsJSON: Codable {
    let install: CatalogueInstallAnalyticsJSON
}

nonisolated struct CatalogueInstallAnalyticsJSON: Codable {
    let days30: Int

    private enum CodingKeys: String, CodingKey {
        case days30 = "30d"
    }
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

    var analyticsInstall30d: Int {
        analytics.install.days30
    }

    var dependencyReferences: [HomebrewPackageReference] {
        HomebrewPackageReference.formulaDependencies(from: dependencies)
    }
}

extension CaskCatalogueItemJSON {
    var description: String {
        desc
    }

    var stableVersion: String {
        versions.stable
    }

    var analyticsInstall30d: Int {
        analytics.install.days30
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
