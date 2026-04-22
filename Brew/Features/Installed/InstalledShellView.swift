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
                if viewModel.shouldShowInitialLoadingIndicator {
                    loadingSkeletonList
                } else {
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

    private var loadingSkeletonList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                InstalledSectionHeader(title: "Formulae", count: 3)
                ForEach(0 ..< 3, id: \.self) { _ in
                    InstalledSkeletonRowView()
                }

                Divider()
                    .overlay(Color.brewBorderSeparator)
                    .padding(.vertical, BrewSpacing.md)

                InstalledSectionHeader(title: "Casks", count: 2)
                ForEach(0 ..< 2, id: \.self) { _ in
                    InstalledSkeletonRowView()
                }
            }
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.xl)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading package list")
    }
}

private struct InstalledSkeletonRowView: View {
    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            Circle()
                .fill(Color.brewSurfaceElevated)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(Color.brewSurfaceElevated)
                    .frame(width: 180, height: 16)

                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(Color.brewSurfaceElevated)
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)

                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(Color.brewSurfaceElevated)
                    .frame(width: 90, height: 10)
            }
        }
        .padding(.vertical, BrewSpacing.sm)
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
