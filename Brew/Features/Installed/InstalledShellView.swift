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

            if let message = viewModel.userFacingError {
                Text(message)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewStatusError)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BrewSpacing.lg)
                    .padding(.bottom, BrewSpacing.sm)
                    .accessibilityLabel(message)
            }

            ZStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.shouldShowFormulaeSection {
                            installedSection(
                                title: "Formulae",
                                rows: viewModel.formulaRows,
                            )
                        }

                        if viewModel.shouldShowInterSectionDivider {
                            Divider()
                                .overlay(Color.brewBorderSeparator)
                                .padding(.vertical, BrewSpacing.md)
                        }

                        if viewModel.shouldShowCasksSection {
                            installedSection(
                                title: "Casks",
                                rows: viewModel.caskRows,
                            )
                        }
                    }
                    .padding(.horizontal, BrewSpacing.lg)
                    .padding(.bottom, BrewSpacing.xl)
                }
                .accessibilityLabel("Installed packages")

                if viewModel.shouldShowInitialLoadingIndicator {
                    ProgressView()
                        .controlSize(.large)
                        .accessibilityLabel(
                            String(localized: "Loading packages", comment: "Installed tab loading a11y"),
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.brewSurface)
        .task {
            await viewModel.load()
        }
    }

    private func installedSection(title: String, rows: [InstalledPackageRow]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            InstalledSectionHeader(title: title, count: rows.count)

            ForEach(rows) { row in
                InstalledListRowView(row: row)
            }
        }
    }
}

#Preview {
    InstalledShellView(
        viewModel: InstalledViewModel(
            previewFormulae: InstalledViewModelDummyData.formulae,
            previewCasks: InstalledViewModelDummyData.casks,
        ),
    )
    .frame(minWidth: 400, minHeight: 500)
}
