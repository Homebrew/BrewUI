//
//  InstalledShellView.swift
//  Brew
//

import SwiftUI

/// Shell for the Installed tab: page chrome and an empty region for the future package list.
struct InstalledShellView: View {
    /// Placeholder until `InstalledViewModel` supplies a real count.
    private let packageCountSubtitle: String = "0 packages"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Installed")
                    .font(.brewTitle1)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(packageCountSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.lg)
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Installed packages")
                .accessibilityHint("List of packages will appear here.")
        }
        .background(Color.brewSurface)
    }
}

#Preview {
    InstalledShellView()
        .frame(minWidth: 400, minHeight: 300)
}
