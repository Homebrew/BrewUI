//
//  PackageSelection.swift
//  Brew
//

import Foundation

/// Identity-only package selection for Installed detail loading/wiring.
struct PackageSelection: Identifiable, Hashable {
    let name: String
    let kind: InstalledPackageKind

    var id: String {
        "\(kind.rawValue):\(name)"
    }
}
