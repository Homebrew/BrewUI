//
//  InstalledPackageDetailView.swift
//  Brew
//

import AppKit
import SwiftUI

/// Root view for the selected row; detail content reads ``EnvironmentValues/brewCommandCenter`` and builds relationship repositories from ``EnvironmentValues/installedInventoryCache``.
struct InstalledPackageDetailRoot: View {
    let selectedPackage: BrewPackage
    let onSelectInstalledPackage: (BrewPackage.ID) -> Void
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.installedInventoryCache) private var installedInventoryCache

    var body: some View {
        InstalledPackageDetailView(
            package: selectedPackage,
            brewCommandCenter: brewCommandCenter,
            installedDependentsRepository: BrewInstalledDependentsRepository(cache: installedInventoryCache),
            installedInventoryReading: BrewInstalledPackagesRepository.live(cache: installedInventoryCache),
            onSelectInstalledPackage: onSelectInstalledPackage,
        )
    }
}

/// Right-hand column: detail for the selected installed package.
struct InstalledPackageDetailView: View {
    let package: BrewPackage
    let onSelectInstalledPackage: (BrewPackage.ID) -> Void
    @State private var viewModel: InstalledDetailsViewModel
    @State private var expandedDependencies = false
    @State private var expandedDependents = false

    private let collapsedRelationshipCount = 3

    init(
        package: BrewPackage,
        brewCommandCenter: BrewCommandCenter,
        installedDependentsRepository: any InstalledDependentsRepository,
        installedInventoryReading: any InstalledInventoryReading,
        onSelectInstalledPackage: @escaping (BrewPackage.ID) -> Void = { _ in },
    ) {
        self.package = package
        self.onSelectInstalledPackage = onSelectInstalledPackage
        _viewModel = State(
            initialValue: InstalledDetailsViewModel(
                package: package,
                brewCommandCenter: brewCommandCenter,
                installedDependentsRepository: installedDependentsRepository,
                installedInventoryReading: installedInventoryReading,
            ),
        )
    }

    var body: some View {
        Group {
            detailScrollContent(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: package.id) {
            await viewModel.refreshRelationships()
            await viewModel.observeRowUpdates()
        }
        .onChange(of: package) { _, newPackage in
            viewModel.update(package: newPackage)
            expandedDependencies = false
            expandedDependents = false
            Task {
                await viewModel.refreshRelationships()
            }
        }
    }

    private func detailScrollContent(viewModel: InstalledDetailsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                InstalledPackageDetailHeroSection(viewModel: viewModel)
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
            InstalledPackageDetailSectionDivider()
            InstalledPackageDetailUpgradeChrome(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func packageDetailsSections(viewModel: InstalledDetailsViewModel) -> some View {
        let package = viewModel.package
        InstalledPackageDetailMetadataSection(package: package)
        InstalledPackageDetailSectionDivider()
        InstalledPackageDetailRelationshipList(
            title: "Dependencies",
            relationships: viewModel.dependencyRelationships,
            dotStyle: .neutral,
            isExpanded: $expandedDependencies,
            collapsedRelationshipCount: collapsedRelationshipCount,
            onSelectInstalledPackage: onSelectInstalledPackage,
        )
        InstalledPackageDetailSectionDivider()
        InstalledPackageDetailUsedBySection(
            viewModel: viewModel,
            collapsedRelationshipCount: collapsedRelationshipCount,
            onSelectInstalledPackage: onSelectInstalledPackage,
            isExpanded: $expandedDependents,
        )
        InstalledPackageDetailSectionDivider()
        InstalledPackageDetailInfoCommandSection(title: "Command", command: viewModel.displayCommand)
    }
}

/// Upgrade affordance and copyable `brew upgrade` command (`CONVENTIONS.md` — transparency).
private struct InstalledPackageDetailUpgradeChrome: View {
    @Bindable var viewModel: InstalledDetailsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Upgrade")
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(Color.brewTextPrimary)

            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                upgradeCommandConsole

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
                if let upgradeError = viewModel.upgradeErrorMessage {
                    Text(upgradeError)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewStatusError)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var upgradeCommandConsole: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Terminal command", systemImage: "terminal")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.upgradeDisplayCommand, forType: .string)
                }
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.sm)
            .background(Color.brewSurfaceRecessed)

            Text(viewModel.upgradeDisplayCommand)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .textSelection(.enabled)

            Text("Upgrades this package to the latest available version")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BrewSpacing.md)
                .padding(.vertical, BrewSpacing.sm)
                .background(Color.brewSurfaceRecessed)
        }
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
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
