//
//  InstalledDeprecatedBadge.swift
//  BrewFeatureInstalled
//

import BrewUIComponents
import SwiftUI

/// Deprecated status pill shared by installed list rows and package detail.
///
/// Filled warning yellow with black label, unlike ``InstalledOutdatedBadge``: deprecation
/// is a standing warning, not a routine upgrade.
struct InstalledDeprecatedBadge: View {
    var body: some View {
        Text(
            String(
                localized: "DEPRECATED",
                bundle: #bundle,
                comment: "Installed deprecated status badge label",
            ),
        )
        .font(.brewCaption2.weight(.semibold))
        .foregroundStyle(Color.brewTextOnBrand)
        .padding(.horizontal, BrewSpacing.sm)
        .padding(.vertical, BrewSpacing.xs)
        .background {
            Capsule()
                .fill(Color.brewStatusWarningBold)
        }
        .accessibilityLabel(
            String(
                localized: "Deprecated",
                bundle: #bundle,
                comment: "Installed deprecated status badge accessibility label",
            ),
        )
    }
}

#Preview {
    InstalledDeprecatedBadge()
        .padding()
}
