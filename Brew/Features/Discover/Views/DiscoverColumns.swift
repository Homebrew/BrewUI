import SwiftUI

/// Entry-point wrapper for the Discover tab content.
struct DiscoverColumnsRoot: View {
    var body: some View {
        DiscoverColumns()
    }
}

struct DiscoverColumns: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Text("Discover")
                .font(.brewLargeTitle)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Discover package browsing will appear here.")
                .font(.brewBody)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
        .background(Color.brewSurfaceBase)
    }
}

#Preview {
    DiscoverColumnsRoot()
}
