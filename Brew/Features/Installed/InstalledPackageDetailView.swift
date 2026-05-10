//
//  InstalledPackageDetailView.swift
//  Brew
//

import SwiftUI

/// Root view for the selected row; detail content reads ``EnvironmentValues/brewCommandCenter`` to build its view model.
struct InstalledPackageDetailRoot: View {
    let selectedPackage: BrewPackage
    @Environment(\.brewCommandCenter) private var brewCommandCenter

    var body: some View {
        InstalledPackageDetailView(
            package: selectedPackage,
            brewCommandCenter: brewCommandCenter,
        )
    }
}

/// Right-hand column: detail for the selected installed package.
struct InstalledPackageDetailView: View {
    let package: BrewPackage
    @State private var viewModel: InstalledDetailsViewModel

    init(package: BrewPackage, brewCommandCenter: BrewCommandCenter) {
        self.package = package
        _viewModel = State(
            initialValue: InstalledDetailsViewModel(
                package: package,
                brewCommandCenter: brewCommandCenter,
            ),
        )
    }

    var body: some View {
        Group {
            detailScrollContent(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: package.id) {
            await viewModel.observeRowUpdates()
        }
        .onChange(of: package) { _, newPackage in
            viewModel.update(package: newPackage)
        }
    }

    private func detailScrollContent(viewModel: InstalledDetailsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                packageHeader(viewModel: viewModel)

                packageDetailsSections(viewModel: viewModel)

                if viewModel.showsUpgradeChrome {
                    upgradeFooter(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func upgradeFooter(viewModel: InstalledDetailsViewModel) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Divider()
                .overlay(Color.brewBorderSeparator)
            InstalledPackageDetailUpgradeChrome(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func packageHeader(viewModel: InstalledDetailsViewModel) -> some View {
        HStack(alignment: .center, spacing: BrewSpacing.sm) {
            Text(viewModel.packageName)
                .font(.brewTitle1)
                .foregroundStyle(Color.brewTextPrimary)

            Text(viewModel.packageKind.rawValue.uppercased())
                .font(.brewCaption2)
                .foregroundStyle(Color.brewTextSecondary)
                .padding(.horizontal, BrewSpacing.xs)
                .padding(.vertical, BrewSpacing.xxs)
                .background(Color.brewSurfaceElevated)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func packageDetailsSections(viewModel: InstalledDetailsViewModel) -> some View {
        let package = viewModel.package
        descriptionSection(package: package)
        detailsSection(package: package)
        dependenciesSection(package: package)
        commandSection(viewModel: viewModel)
    }

    private func descriptionSection(package: BrewPackage) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Description")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            Text(descriptionText(package))
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)
        }
    }

    private func detailsSection(package: BrewPackage) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Details")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            detailRow(label: "Version", value: versionColumnValue(package.latestVersion))
            detailRow(label: "Installed", value: installedValue(package))
            if let homepageURL = package.homepageURL {
                homepageRow(url: homepageURL)
            }
        }
    }

    private func dependenciesSection(package: BrewPackage) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Dependencies")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            if package.dependencies.isEmpty {
                Text("No dependencies")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                dependencyGrid(package.dependencies)
            }
        }
    }

    private func dependencyGrid(_ dependencies: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120), spacing: BrewSpacing.sm)],
            spacing: BrewSpacing.sm,
        ) {
            ForEach(dependencies, id: \.self) { dependency in
                Text(dependency)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BrewSpacing.sm)
                    .padding(.vertical, BrewSpacing.xs)
                    .background(Color.brewSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrewRadius.sm)
                            .stroke(Color.brewBorderDefault, lineWidth: 1),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm))
            }
        }
    }

    private func commandSection(viewModel: InstalledDetailsViewModel) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Command")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            Text(viewModel.displayCommand)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
                .textSelection(.enabled)
        }
    }

    private func versionColumnValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 70, alignment: .leading)
            detailValueView(value)
            Spacer(minLength: 0)
        }
    }

    private func homepageRow(url: URL) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text("Homepage")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 70, alignment: .leading)
            Link(destination: url) {
                Text(url.absoluteString)
                    .font(.brewCallout)
            }
            Spacer(minLength: 0)
        }
    }

    private func detailValueView(_ value: String) -> some View {
        Text(value)
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextPrimary)
            .textSelection(.enabled)
    }

    private func descriptionText(_ package: BrewPackage) -> String {
        let fallback = String(
            localized: "No description available.",
            comment: "Installed detail fallback description when no summary is available",
        )
        let trimmed = package.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func installedValue(_ package: BrewPackage) -> String {
        if package.installedVersions.isEmpty {
            return "—"
        }
        return package.installedVersions.joined(separator: ", ")
    }
}

/// Upgrade affordance and copyable `brew upgrade` command (`CONVENTIONS.md` — transparency).
private struct InstalledPackageDetailUpgradeChrome: View {
    @Bindable var viewModel: InstalledDetailsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Upgrade")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)

            if let title = viewModel.upgradePrimaryButtonTitle {
                HStack(spacing: BrewSpacing.sm) {
                    Button {
                        viewModel.upgradeSelectedPackage()
                    } label: {
                        if viewModel.isUpgrading {
                            ProgressView()
                                .controlSize(.small)
                                .frame(minWidth: 120)
                        } else {
                            Text(title)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isUpgrading)
                    .accessibilityLabel(title)
                }
            }

            Text("Command")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            Text(viewModel.upgradeDisplayCommand)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
                .textSelection(.enabled)

            if let upgradeError = viewModel.upgradeErrorMessage {
                Text(upgradeError)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewStatusError)
            }
        }
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
