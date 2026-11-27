//
//  PackageDetailSubviews.swift
//  BrewUIComponents
//

import SwiftUI

/// Section heading used across package-detail surfaces.
public struct PackageDetailSectionHeading: View {
    let title: LocalizedStringResource

    public init(title: LocalizedStringResource) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.brewSubheadline.weight(.semibold))
            .foregroundStyle(Color.brewTextPrimary)
    }
}

/// Native divider between package-detail sections, without an additional colour layer.
public struct PackageDetailSectionDivider: View {
    public init() {}

    public var body: some View {
        Divider()
    }
}
