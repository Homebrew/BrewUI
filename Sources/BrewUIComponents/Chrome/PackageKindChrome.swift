//
//  PackageKindChrome.swift
//  BrewUIComponents
//

import BrewCore
import Foundation

/// Semantic colour roles for mapping to `Color` in SwiftUI (design tokens in one place).
public enum PackageKindAccentToken: Equatable {
    case brandPrimary
    case statusInfo
}

public enum PackageKindIconBackgroundToken: Equatable {
    case brandTint
    case statusInfoSubtle
}

/// Testable chrome for an installed list row (badge + token roles); views map tokens to `Color`.
public struct PackageKindChrome: Equatable {
    public var badgeLabel: String
    public var accent: PackageKindAccentToken
    public var iconBackground: PackageKindIconBackgroundToken

    public init(
        badgeLabel: String,
        accent: PackageKindAccentToken,
        iconBackground: PackageKindIconBackgroundToken,
    ) {
        self.badgeLabel = badgeLabel
        self.accent = accent
        self.iconBackground = iconBackground
    }
}

public extension HomebrewPackageKind {
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
