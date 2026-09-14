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
    @Environment(\.brewLocalization) private var localization
    var body: some View {
        Text(
            localization.string("OUTDATED"),
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
            localization.string("Upgrade available"),
        )
    }
}

#Preview {
    InstalledOutdatedBadge()
        .padding()
}
