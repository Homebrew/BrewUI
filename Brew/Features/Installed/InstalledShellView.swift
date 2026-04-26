//
//  InstalledShellView.swift
//  Brew
//

import SwiftUI

/// Middle column of the main window: “Installed” chrome and the package list.
struct InstalledShellView: View {
    @Bindable var viewModel: InstalledViewModel

    var body: some View {
        installedListContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var installedListContent: some View {
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
                if viewModel.shouldShowInitialLoadingIndicator {
                    loadingSkeletonList
                } else {
                    List {
                        if viewModel.shouldShowFormulaeSection {
                            Section("Formulae") {
                                ForEach(viewModel.formulaRows) { row in
                                    InstalledListRowView(row: row)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.toggleSelection(for: row.id)
                                        }
                                        .listRowBackground(
                                            viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear
                                        )
                                }
                            }
                        }

                        if viewModel.shouldShowCasksSection {
                            Section("Casks") {
                                ForEach(viewModel.caskRows) { row in
                                    InstalledListRowView(row: row)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.toggleSelection(for: row.id)
                                        }
                                        .listRowBackground(
                                            viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear
                                        )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityLabel("Installed packages")
                    .onExitCommand {
                        viewModel.clearSelection()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var loadingSkeletonList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                InstalledSectionHeader(title: "Formulae", count: 3)
                ForEach(loadingFormulaeRows) { row in
                    InstalledListRowView(row: row)
                }
            }
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.xl)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading package list")
    }

    private var loadingFormulaeRows: [InstalledPackageRow] {
        [
            InstalledPackageRow(
                name: "Placeholder Formula",
                kind: .formula,
                description: "Placeholder description text for loading row shell.",
                installedVersion: "v0.0.0",
            ),
            InstalledPackageRow(
                name: "Placeholder Formula",
                kind: .formula,
                description: "Placeholder description text for loading row shell.",
                installedVersion: "v0.0.0",
            ),
            InstalledPackageRow(
                name: "Placeholder Formula",
                kind: .formula,
                description: "Placeholder description text for loading row shell.",
                installedVersion: "v0.0.0",
            ),
        ]
    }
}

/// Right-hand column: detail for the selected installed package.
struct InstalledPackageDetailView: View {
    let row: InstalledPackageRow

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            HStack(alignment: .center, spacing: BrewSpacing.sm) {
                Text(row.name)
                    .font(.brewTitle1)
                    .foregroundStyle(Color.brewTextPrimary)

                Text(row.kind.rawValue.uppercased())
                    .font(.brewCaption2)
                    .foregroundStyle(Color.brewTextSecondary)
                    .padding(.horizontal, BrewSpacing.xs)
                    .padding(.vertical, BrewSpacing.xxs)
                    .background(Color.brewSurfaceElevated)
                    .clipShape(Capsule())
            }

            Text("Installed: \(row.installedVersion)")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)

            if row.hasDescription {
                Text(row.description)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextPrimary)
            } else {
                Text("Package detail content will be expanded in the next step.")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            }

            Spacer()
        }
        .padding(BrewSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Empty third column when no package is selected.
struct InstalledPackageDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Choose a package from the list to see details.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
    }
}

#Preview("List column") {
    InstalledShellView(
        viewModel: InstalledViewModel(
            previewFormulae: InstalledViewModelDummyData.formulae,
            previewCasks: InstalledViewModelDummyData.casks,
        ),
    )
    .frame(minWidth: 360, minHeight: 500)
}

#Preview("Detail") {
    InstalledPackageDetailView(
        row: InstalledViewModelDummyData.formulae[0],
    )
    .frame(minWidth: 280, minHeight: 200)
}
