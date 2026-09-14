//
//  PackageDetailSubviews.swift
//  BrewUIComponents
//

import SwiftUI

/// Section heading used across package-detail surfaces.
public struct PackageDetailSectionHeading: View {
    @Environment(\.brewLocalization) private var localization

    let title: String.LocalizationValue

    public init(title: String.LocalizationValue) {
        self.title = title
    }

    public var body: some View {
        Text(localization.string(title))
            .font(.brewSubheadline.weight(.semibold))
            .foregroundStyle(Color.brewTextPrimary)
    }
}

/// Hairline divider between package-detail sections.
public struct PackageDetailSectionDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .overlay(Color.brewBorderSeparator)
    }
}
