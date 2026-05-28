//
//  CatalogueRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

@MainActor
public protocol CatalogueRepository: Sendable {
    func package(for reference: HomebrewPackageID) async throws -> BrewPackage?
    /// Catalogue-wide name search across both formulae and casks, capped at `limit` results.
    func searchPackages(matching query: String, limit: Int) async throws -> [BrewPackage]
}
