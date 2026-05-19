//
//  CatalogueCacheEnvironment.swift
//  Brew
//

import SwiftUI

extension EnvironmentValues {
    /// Inject from ``BrewApp``; otherwise a default cache is created for previews and unscoped subtrees.
    @Entry var catalogueCache = CatalogueCache()
}
