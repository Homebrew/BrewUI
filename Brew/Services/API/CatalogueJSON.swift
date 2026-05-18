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
}

nonisolated struct CaskCatalogueItemJSON: Codable {
    let name: String
    let desc: String
    let homepage: String
    let versions: CatalogueVersionsJSON
    let analytics: CatalogueAnalyticsJSON
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
