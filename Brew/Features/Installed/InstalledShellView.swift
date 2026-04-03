//
//  InstalledShellView.swift
//  Brew
//

import SwiftUI

/// Shell for the Installed tab: page chrome and scrollable list of packages.
struct InstalledShellView: View {
    @Bindable var viewModel: InstalledViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Installed")
                    .font(.brewTitle1)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.packageCountSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.lg)
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    installedSection(
                        title: "Formulae",
                        rows: viewModel.formulaRows,
                    )

                    Divider()
                        .overlay(Color.brewBorderSeparator)
                        .padding(.vertical, BrewSpacing.md)

                    installedSection(
                        title: "Casks",
                        rows: viewModel.caskRows,
                    )
                }
                .padding(.horizontal, BrewSpacing.lg)
                .padding(.bottom, BrewSpacing.xl)
            }
            .accessibilityLabel("Installed packages")
        }
        .background(Color.brewSurface)
    }

    @ViewBuilder
    private func installedSection(title: String, rows: [InstalledPackageRow]) -> some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                InstalledSectionHeader(title: title, count: rows.count)

                ForEach(rows) { row in
                    InstalledListRowView(row: row)
                }
            }
        }
    }
}

#Preview {
    InstalledShellView(viewModel: InstalledViewModel())
        .frame(minWidth: 400, minHeight: 500)
}
