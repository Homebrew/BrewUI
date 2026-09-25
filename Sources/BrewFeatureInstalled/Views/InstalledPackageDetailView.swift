//
//  InstalledPackageDetailView.swift
//  Brew
//

import AppKit
import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Root view for the selected row; reads the command center, command factory, and dependents
/// repository from the environment and injects them into the detail content's view model.
struct InstalledPackageDetailRoot: View {
    let selectedPackage: InstalledBrewPackage
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory
    @Environment(\.installedDependentsRepository) private var installedDependentsRepository
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    var body: some View {
        InstalledPackageDetailView(
            package: selectedPackage,
            brewCommandCenter: brewCommandCenter,
            mutatingCommandFactory: mutatingCommandFactory,
            installedDependentsRepository: installedDependentsRepository,
            installedInventoryReading: installedPackagesRepository,
            fetchRevision: installedPackagesRepository.fetchRevision,
            onSelectInstalledPackage: onSelectInstalledPackage,
        )
    }
}

/// Right-hand column: detail for the selected installed package.
struct InstalledPackageDetailView: View {
    let package: InstalledBrewPackage
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void
    /// Settled inventory fetches, fed from the environment by ``InstalledPackageDetailRoot``
    /// (`0` in previews). A change releases the busy latch when the reconcile settled without
    /// changing this package.
    let fetchRevision: Int
    @State private var viewModel: InstalledPackageDetailViewModel

    init(
        package: InstalledBrewPackage,
        brewCommandCenter: any BrewCommandCenter,
        mutatingCommandFactory: any BrewMutatingCommandFactory,
        installedDependentsRepository: any InstalledDependentsRepository,
        installedInventoryReading: any InstalledInventoryReading,
        fetchRevision: Int = 0,
        onSelectInstalledPackage: @escaping (InstalledBrewPackage.ID) -> Void = { _ in },
    ) {
        self.package = package
        self.onSelectInstalledPackage = onSelectInstalledPackage
        self.fetchRevision = fetchRevision
        _viewModel = State(
            initialValue: InstalledPackageDetailViewModel(
                package: package,
                brewCommandCenter: brewCommandCenter,
                commandFactory: mutatingCommandFactory,
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
        .accessibilityElement(children: .contain)
        .axid(.packageDetail)
        .task(id: package.id) {
            await viewModel.refreshRelationships()
        }
        .task(id: viewModel.operationSubject) {
            await viewModel.observeRowUpdates()
        }
        .onChange(of: package) { _, newPackage in
            viewModel.update(package: newPackage)
            Task {
                await viewModel.refreshRelationships()
            }
        }
        .onChange(of: fetchRevision) {
            viewModel.releaseLatchedOperationState()
        }
    }

    private func detailScrollContent(viewModel: InstalledPackageDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                InstalledPackageDetailHeroSection(viewModel: viewModel)
                packageDetailsSections(viewModel: viewModel)
                packageActionsFooter(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
            .brewPaneContentWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func packageActionsFooter(viewModel: InstalledPackageDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xl) {
            PackageDetailSectionDivider()
            if viewModel.upgradeItem.showsUpgradeChrome {
                InstalledPackageDetailUpgradeChrome(viewModel: viewModel)
                PackageDetailSectionDivider()
            }
            InstalledPackageDetailUninstallChrome(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func packageDetailsSections(viewModel: InstalledPackageDetailViewModel) -> some View {
        InstalledPackageDetailMetadataSection(viewModel: viewModel)
        PackageDetailSectionDivider()
        PackageRelationshipSection(
            title: LocalizedStringResource("Dependencies", bundle: #bundle, comment: "Package detail section heading"),
            relationships: viewModel.dependencyRelationships,
            emptyText: LocalizedStringResource("No dependencies.", bundle: #bundle, comment: "Package detail: empty dependency list"),
            dotStyle: .neutral,
            onSelectInstalledPackage: onSelectInstalledPackage,
        )
        PackageDetailSectionDivider()
        InstalledPackageDetailDependentsSection(
            viewModel: viewModel,
            onSelectInstalledPackage: onSelectInstalledPackage,
        )
    }
}

/// Heading + always-expanded relationship list, used for Dependencies.
private struct PackageRelationshipSection: View {
    let title: LocalizedStringResource
    let relationships: [PackageRelationshipItem]
    let emptyText: LocalizedStringResource
    let dotStyle: PackageRelationshipDotStyle
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: title)
            if relationships.isEmpty {
                Text(emptyText)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                InstalledPackageDetailRelationshipList(
                    relationships: relationships,
                    dotStyle: dotStyle,
                    onSelectInstalledPackage: onSelectInstalledPackage,
                )
            }
        }
    }
}

/// Uninstall affordance and copyable `brew uninstall` command (`ARCHITECTURE.md` — transparency).
private struct InstalledPackageDetailUninstallChrome: View {
    @Bindable var viewModel: InstalledPackageDetailViewModel

    var body: some View {
        let uninstall = viewModel.uninstallItem
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Uninstall", bundle: #bundle, comment: "Package detail section heading")
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(Color.brewTextPrimary)

            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                CommandBlockView(
                    command: uninstall.displayCommand,
                    summaryText: LocalizedStringResource("Uninstalls this package from this Mac", bundle: #bundle, comment: "Command block summary above brew uninstall"),
                )

                Button {
                    viewModel.handleUninstallPrimaryButtonTapped()
                } label: {
                    if viewModel.isUninstalling {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 120)
                    } else {
                        Text(uninstall.primaryButtonTitle)
                            .foregroundStyle(
                                viewModel.showsUninstallBlockedPrimaryButtonChrome
                                    ? Color.brewTextTertiary
                                    : Color.brewTextSecondary,
                            )
                    }
                }
                .buttonStyle(.bordered)
                .opacity(viewModel.showsUninstallBlockedPrimaryButtonChrome ? 0.65 : 1)
                .disabled(viewModel.isMutatingPackage)
                .accessibilityLabel(uninstall.primaryButtonTitle)
                .accessibilityHint(uninstall.blockedPrimaryButtonAccessibilityHint ?? "")
                .axid(.uninstallButton)
                .confirmationDialog(
                    uninstall.confirmationTitle,
                    isPresented: $viewModel.showUninstallConfirmation,
                ) {
                    Button(uninstall.primaryButtonTitle, role: .destructive) {
                        viewModel.uninstallSelectedPackage()
                    }
                    Button(String(localized: "Cancel", bundle: #bundle, comment: "Uninstall confirmation: keep the package"), role: .cancel) {}
                } message: {
                    Text(uninstall.confirmationMessage)
                }

                if viewModel.showUninstallBlockedCallout,
                   let callout = uninstall.blockedCalloutContent
                {
                    UninstallBlockedCallout(lead: callout.lead, bodyText: callout.body)
                }

                if let uninstallError = viewModel.uninstallErrorMessage {
                    Text(uninstallError)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewStatusError)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

/// Upgrade affordance and copyable `brew upgrade` command (`ARCHITECTURE.md` — transparency).
private struct InstalledPackageDetailUpgradeChrome: View {
    @Bindable var viewModel: InstalledPackageDetailViewModel

    var body: some View {
        let upgrade = viewModel.upgradeItem
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Upgrade", bundle: #bundle, comment: "Package detail section heading")
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(Color.brewTextPrimary)

            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                CommandBlockView(
                    command: upgrade.displayCommand,
                    summaryText: LocalizedStringResource(
                        "Upgrades this package to the latest available version",
                        bundle: #bundle,
                        comment: "Command block summary above brew upgrade",
                    ),
                )

                if let title = upgrade.primaryButtonTitle {
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
                        .axid(.upgradeButton)
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
}

/// Empty third column when no package is selected.
struct InstalledPackageDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection", bundle: #bundle, comment: "Package detail placeholder title when nothing is selected")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Choose a package from the list to see details.", bundle: #bundle, comment: "Package detail placeholder body when nothing is selected")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
        .brewPaneContentWidth()
    }
}

#if DEBUG

    #Preview("Installed detail") {
        InstalledPackageDetailView(
            package: PreviewSupport.outdatedFormula,
            brewCommandCenter: PreviewSupport.commandCenter,
            mutatingCommandFactory: PreviewSupport.mutatingCommandFactory,
            installedDependentsRepository: PreviewSupport.makeInstalledDependentsRepository(),
            installedInventoryReading: PreviewSupport.makeInstalledInventoryReading(),
        )
        .frame(minWidth: 340, minHeight: 320)
    }
#endif
