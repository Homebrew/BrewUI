//
//  InstalledShellView.swift
//  Brew
//

import SwiftUI

/// Shell for the Installed tab: page chrome and scrollable list of packages.
struct InstalledShellView: View {
    @Bindable var viewModel: InstalledViewModel

    var body: some View {
        HSplitView {
            installedMasterPanel
                .frame(minWidth: 360, idealWidth: 460)

            if let selectedRow = viewModel.selectedPackageRow {
                InstalledDetailSelectionView(row: selectedRow)
                    .frame(minWidth: BrewLayout.inspectorWidth)
            } else {
                Color.clear
                    .frame(minWidth: BrewLayout.inspectorWidth)
            }
        }
        .task {
            await viewModel.load()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var installedMasterPanel: some View {
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
                                            viewModel.selectedPackageID = row.id
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
                                            viewModel.selectedPackageID = row.id
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

private struct InstalledDetailSelectionView: View {
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

#Preview {
    InstalledShellView(
        viewModel: InstalledViewModel(
            previewFormulae: InstalledViewModelDummyData.formulae,
            previewCasks: InstalledViewModelDummyData.casks,
        ),
    )
    .frame(minWidth: 400, minHeight: 500)
}
