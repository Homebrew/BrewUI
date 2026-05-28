//
//  PackageKindChrome.swift
//  Brew
//

import Foundation

/// Semantic colour roles for mapping to `Color` in SwiftUI (design tokens in one place).
nonisolated enum PackageKindAccentToken: Equatable {
    case brandPrimary
    case statusInfo
}

nonisolated enum PackageKindIconBackgroundToken: Equatable {
    case brandTint
    case statusInfoSubtle
}

/// Testable chrome for an installed list row (badge + token roles); views map tokens to `Color`.
nonisolated struct PackageKindChrome: Equatable {
    var badgeLabel: String
    var accent: PackageKindAccentToken
    var iconBackground: PackageKindIconBackgroundToken
}

nonisolated extension HomebrewPackageKind {
    var chrome: PackageKindChrome {
        switch self {
        case .formula:
            PackageKindChrome(
                badgeLabel: "FORMULA",
                accent: .brandPrimary,
                iconBackground: .brandTint,
            )
        case .cask:
            PackageKindChrome(
                badgeLabel: "CASK",
                accent: .statusInfo,
                iconBackground: .statusInfoSubtle,
            )
        }
    }
}
