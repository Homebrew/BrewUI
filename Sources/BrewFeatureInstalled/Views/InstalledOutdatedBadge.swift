//
//  InstalledOutdatedBadge.swift
//  BrewFeatureInstalled
//

import BrewUIComponents
import SwiftUI

/// Outdated status pill shared by installed list rows and package detail.
///
/// Outlined like the kind pill it sits beside, and neutral rather than warning-coloured: an
/// available upgrade is routine, and the version line underneath already carries the amber.
struct InstalledOutdatedBadge: View {
    var body: some View {
        Text(
            String(
                localized: "OUTDATED",
                comment: "Installed outdated status badge label",
            ),
        )
        .font(.brewCaption2)
        .foregroundStyle(Color.brewTextSecondary)
        .padding(.horizontal, BrewSpacing.sm)
        .padding(.vertical, BrewSpacing.xs)
        .background {
            Capsule()
                .fill(Color.brewSurfaceElevated)
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
        }
        .accessibilityLabel(
            String(
                localized: "Update available",
                comment: "Installed outdated status badge accessibility label",
            ),
        )
    }
}

#Preview {
    InstalledOutdatedBadge()
        .padding()
}
