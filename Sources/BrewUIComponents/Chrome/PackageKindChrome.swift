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

/// Testable chrome for an installed list row (badge + token role); views map tokens to `Color`.
///
/// The accent drives the badge label and the icon chip, which is an outline — no background role.
public struct PackageKindChrome: Equatable {
    public var badgeLabel: String
    public var accent: PackageKindAccentToken

    public init(
        badgeLabel: String,
        accent: PackageKindAccentToken,
    ) {
        self.badgeLabel = badgeLabel
        self.accent = accent
    }
}

public extension HomebrewPackageKind {
    var chrome: PackageKindChrome {
        switch self {
        case .formula:
            PackageKindChrome(
                badgeLabel: "FORMULA",
                accent: .brandPrimary,
            )
        case .cask:
            PackageKindChrome(
                badgeLabel: "CASK",
                accent: .statusInfo,
            )
        }
    }
}
