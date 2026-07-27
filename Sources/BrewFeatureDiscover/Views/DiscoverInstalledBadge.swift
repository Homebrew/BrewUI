import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Installed status pill shared by discover list rows and package detail.
struct DiscoverInstalledBadge: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.xs) {
            Image(systemName: "checkmark.circle")
            Text(
                String(
                    localized: "INSTALLED",
                    comment: "Discover installed status badge label",
                ),
            )
        }
        .font(.brewCaption2)
        .foregroundStyle(Color.brewStatusSuccess)
        .padding(.horizontal, BrewSpacing.sm)
        .padding(.vertical, BrewSpacing.xs)
        .background {
            Capsule()
                .fill(Color.brewStatusSuccessSubtle)
        }
        .accessibilityLabel(
            String(
                localized: "Installed",
                comment: "Discover installed status badge accessibility label",
            ),
        )
    }
}

#Preview {
    DiscoverInstalledBadge()
        .padding()
}
