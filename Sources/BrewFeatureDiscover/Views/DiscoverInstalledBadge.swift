import BrewUIComponents
import SwiftUI

/// Installed status pill shared by discover list rows and package detail.
struct DiscoverInstalledBadge: View {
    @Environment(\.brewLocalization) private var localization
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.xs) {
            Image(systemName: "checkmark.circle")
            Text(
                localization.string("INSTALLED"),
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
            localization.string("Installed"),
        )
    }
}

#Preview {
    DiscoverInstalledBadge()
        .padding()
}
