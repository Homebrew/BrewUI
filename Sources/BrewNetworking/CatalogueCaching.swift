//
//  CatalogueCaching.swift
//  Brew
//

import Foundation

public protocol CatalogueCaching: Sendable {
    func formulaCatalogue() async -> FormulaCatalogueJSON?
    func caskCatalogue() async -> CaskCatalogueJSON?
    func etag(for kind: CatalogueCache.CatalogueKind) async -> String?
    func updateFormulaCatalogue(with rawData: Data, etag: String?) async throws
    func updateCaskCatalogue(with rawData: Data, etag: String?) async throws
}
