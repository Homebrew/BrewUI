//
//  InstalledPackageDetailView.swift
//  Brew
//

import SwiftUI

/// Right-hand column: detail for the selected installed package.
struct InstalledPackageDetailView: View {
    @Bindable var viewModel: InstalledDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                packageHeader

                switch viewModel.state {
                case .loading:
                    loadingSkeletonDetails
                case let .error(detailsUserFacingError):
                    Text(detailsUserFacingError)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewStatusError)
                case let .loaded(details):
                    packageDetailsSections(details: details)
                }

                if viewModel.showsUpgradeChrome {
                    upgradeFooter
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var upgradeFooter: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Divider()
                .overlay(Color.brewBorderSeparator)
            InstalledPackageDetailUpgradeChrome(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var packageHeader: some View {
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
    private func packageDetailsSections(details: InstalledPackageDetails) -> some View {
        descriptionSection(details: details)
        detailsSection(details: details)
        dependenciesSection(details: details)
        commandSection
    }

    private func descriptionSection(details: InstalledPackageDetails) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Description")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            Text(descriptionText(details))
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)
        }
    }

    private func detailsSection(details: InstalledPackageDetails) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Details")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            detailRow(label: "Version", value: details.version ?? "—")
            detailRow(label: "Installed", value: installedValue(details))
            if let homepageURL = viewModel.homepageURL {
                homepageRow(url: homepageURL)
            }
        }
    }

    private func dependenciesSection(details: InstalledPackageDetails) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Dependencies")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
            if details.dependencies.isEmpty {
                Text("No dependencies")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                dependencyGrid(details.dependencies)
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

    private var commandSection: some View {
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

    private func descriptionText(_ details: InstalledPackageDetails) -> String {
        let fallback = String(
            localized: "No description available.",
            comment: "Installed detail fallback description when no summary is available",
        )
        let trimmed = details.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func installedValue(_ details: InstalledPackageDetails) -> String {
        if details.installedVersions.isEmpty {
            return "—"
        }
        return details.installedVersions.joined(separator: ", ")
    }

    private var loadingSkeletonDetails: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xl) {
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                Text("Description")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
                Text("Placeholder description for package details loading state.")
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextPrimary)
            }

            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                Text("Details")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
                detailRow(label: "Version", value: "v0.0.0")
                detailRow(label: "Installed", value: "v0.0.0")
                detailRow(label: "Homepage", value: "https://example.com")
            }

            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                Text("Dependencies")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: BrewSpacing.sm)],
                    spacing: BrewSpacing.sm,
                ) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        Text("placeholder-dependency")
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

            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                Text("Command")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
                Text("brew info placeholder")
                    .font(.brewCode)
                    .foregroundStyle(Color.brewCodeDefault)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BrewSpacing.md)
                    .background(Color.brewTerminal)
                    .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading package details")
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
