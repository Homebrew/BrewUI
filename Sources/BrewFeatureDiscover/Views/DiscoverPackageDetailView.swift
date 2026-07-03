import AppKit
import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Root view for the selected row; reads the installed repository, command center, and command
/// factory from the environment and injects them into the detail content's view model.
struct DiscoverPackageDetailRoot: View {
    let selectedPackage: DiscoveryBrewPackage
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory

    var body: some View {
        DiscoverPackageDetailView(
            package: selectedPackage,
            installedRepository: installedPackagesRepository,
            brewCommandCenter: brewCommandCenter,
            mutatingCommandFactory: mutatingCommandFactory,
        )
    }
}

/// Right-hand column: detail for the selected discovery package.
struct DiscoverPackageDetailView: View {
    let package: DiscoveryBrewPackage
    @State private var viewModel: DiscoverPackageDetailViewModel

    init(
        package: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
        brewCommandCenter: any BrewCommandCenter,
        mutatingCommandFactory: any BrewMutatingCommandFactory,
    ) {
        self.package = package
        _viewModel = State(
            initialValue: DiscoverPackageDetailViewModel(
                package: package,
                installedRepository: installedRepository,
                brewCommandCenter: brewCommandCenter,
                commandFactory: mutatingCommandFactory,
            ),
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                DiscoverPackageDetailHeroSection(viewModel: viewModel)
                DiscoverPackageDetailMetadataSection(viewModel: viewModel)
                PackageDetailSectionDivider()
                DiscoverPackageDetailDependenciesSection(viewModel: viewModel)
                if viewModel.showsInstallSection {
                    PackageDetailSectionDivider()
                    DiscoverPackageInstallSection(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: package) {
            await viewModel.observeInstallUpdates()
        }
        .onChange(of: package) { _, newPackage in
            viewModel.update(package: newPackage)
        }
    }
}

private struct DiscoverPackageDetailHeroSection: View {
    let viewModel: DiscoverPackageDetailViewModel

    var body: some View {
        let chrome = viewModel.packageKindChrome
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: BrewRadius.lg)
                    .fill(iconBackgroundColor(chrome.iconBackground))
                    .frame(width: 44, height: 44)
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor(chrome.accent))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                HStack(spacing: BrewSpacing.sm) {
                    Text(viewModel.name)
                        .font(.brewTitle1)
                        .foregroundStyle(Color.brewTextPrimary)

                    Text(chrome.badgeLabel)
                        .font(.brewCaption2)
                        .foregroundStyle(accentColor(chrome.accent))
                        .padding(.horizontal, BrewSpacing.xs)
                        .padding(.vertical, BrewSpacing.xxs)
                        .background {
                            Capsule()
                                .fill(Color.brewSurfaceElevated)
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
                        }

                    if viewModel.installedStatusLabel != nil {
                        DiscoverInstalledBadge()
                    }
                }

                if let description = viewModel.packageDescription {
                    Text(description)
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
        }
    }

    private func accentColor(_ token: PackageKindAccentToken) -> Color {
        switch token {
        case .brandPrimary: Color.brewBrandPrimary
        case .statusInfo: Color.brewStatusInfo
        }
    }

    private func iconBackgroundColor(_ token: PackageKindIconBackgroundToken) -> Color {
        switch token {
        case .brandTint: Color.brewBrandTint
        case .statusInfoSubtle: Color.brewStatusInfoSubtle
        }
    }
}

private struct DiscoverPackageDetailMetadataSection: View {
    let viewModel: DiscoverPackageDetailViewModel

    private let labelWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Details")
            if let installedVersion = viewModel.installedVersionLabel {
                detailRow(
                    label: "Installed",
                    value: installedVersion,
                    valueColor: viewModel.isInstalledVersionOutdated ? .brewStatusWarning : .brewTextPrimary,
                    valueFontWeight: .heavy,
                )
            }
            detailRow(label: "Latest stable", value: viewModel.stableVersionLabel)
            if viewModel.showsInstallMetrics {
                detailRow(label: "30-day installs", value: viewModel.installs30DayLabel)
            }
            if let dateValue = viewModel.installDateValue {
                detailRow(label: "Installed on", value: dateValue)
            }
            if let reason = viewModel.installReasonValue {
                detailRow(label: "Install reason", value: reason)
            }
            if let license = viewModel.licenseLabel {
                detailRow(label: "License", value: license)
            }
            if let tap = viewModel.tapDisplayValue {
                sourceRow(tap: tap, url: viewModel.sourceURL)
            }
            if let url = viewModel.homepageURL {
                homepageRow(url: url)
            }
        }
    }

    private func detailRow(label: String, value: String, valueColor: Color = .brewTextPrimary, valueFontWeight: Font.Weight = .medium) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(.brewCallout.weight(valueFontWeight))
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func sourceRow(tap: String, url: URL?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text("Source")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            if let url {
                Link(destination: url) {
                    HStack(spacing: BrewSpacing.xxs) {
                        Text(tap)
                            .font(.brewCallout.weight(.medium))
                        Image(systemName: "arrow.up.right")
                            .font(.brewCaption2)
                    }
                }
            } else {
                Text(tap)
                    .font(.brewCallout.weight(.medium))
                    .foregroundStyle(Color.brewTextPrimary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }

    private func homepageRow(url: URL) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text("Homepage")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Link(destination: url) {
                HStack(spacing: BrewSpacing.xxs) {
                    Text(url.host ?? url.absoluteString)
                        .font(.brewCallout.weight(.medium))
                    Image(systemName: "arrow.up.right")
                        .font(.brewCaption2)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct DiscoverPackageDetailDependenciesSection: View {
    let viewModel: DiscoverPackageDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            PackageDetailSectionHeading(title: "Dependencies")
            let deps = viewModel.dependencyNames
            if deps.isEmpty {
                Text("No dependencies.")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                ForEach(deps, id: \.self) { name in
                    HStack(spacing: BrewSpacing.sm) {
                        Circle()
                            .fill(Color.brewTextTertiary)
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.brewCode)
                            .foregroundStyle(Color.brewTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, BrewSpacing.xs)
                }
            }
        }
    }
}

private struct DiscoverPackageInstallSection: View {
    let viewModel: DiscoverPackageDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Install")
            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                CommandBlockView(
                    command: viewModel.installCommand,
                    summaryText: "Installs this package on your Mac",
                )

                Button {
                    viewModel.installSelectedPackage()
                } label: {
                    if viewModel.isInstalling {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 120)
                    } else {
                        Text("Install")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isInstalling)
                .accessibilityLabel(Text("Install"))

                if let installErrorMessage = viewModel.installErrorMessage {
                    Text(installErrorMessage)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewStatusError)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct DiscoverPackageDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Choose a package from Discover to see details.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
    }
}

#if DEBUG

    #Preview {
        DiscoverPackageDetailView(
            package: PreviewSupport.discoverPreviewPackage,
            installedRepository: PreviewSupport.makeInstalledPackagesRepository(),
            brewCommandCenter: PreviewSupport.commandCenter,
            mutatingCommandFactory: PreviewSupport.mutatingCommandFactory,
        )
        .frame(minWidth: 380, minHeight: 480)
    }
#endif
