//
//  BrewOperationID+Homebrew.swift
//  Brew
//

import Foundation

extension BrewOperationID {
    /// Stable id from domain package kind + name (`kind:name`, matches Homebrew list-stable strings).
    init(kind: HomebrewPackageKind, name: String) {
        rawValue = "\(kind.rawValue):\(name)"
    }
}
