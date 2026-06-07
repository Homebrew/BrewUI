//
//  PackageDetailSubviews.swift
//  BrewUIComponents
//

import SwiftUI

/// Section heading used across package-detail surfaces.
public struct PackageDetailSectionHeading: View {
    let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
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
