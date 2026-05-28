import AppKit
import SwiftUI

/// Root view for the selected row; detail content reads ``EnvironmentValues/brewCommandCenter`` and builds relationship repositories from ``EnvironmentValues/installedInventoryCache``.
struct DiscoverPackageDetailRoot: View {
    let selectedPackage: DiscoveryBrewPackage
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    var body: some View {
        DiscoverPackageDetailView(
            package: selectedPackage,
            installedRepository: installedPackagesRepository,
        )
    }
}

/// Right-hand column: detail for the selected discovery package.
struct DiscoverPackageDetailView: View {
    let package: DiscoveryBrewPackage
    @State private var viewModel: DiscoverPackageDetailViewModel
    @State private var expandedDependencies = false

    private let collapsedDependencyCount = 3

    init(
        package: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
    ) {
        self.package = package
        _viewModel = State(
            initialValue: DiscoverPackageDetailViewModel(
                package: package,
                installedRepository: installedRepository,
            ),
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                DiscoverPackageDetailHeroSection(viewModel: viewModel)
                DiscoverPackageDetailMetadataSection(viewModel: viewModel)
                PackageDetailSectionDivider()
                DiscoverPackageDetailDependenciesSection(
                    viewModel: viewModel,
                    collapsedCount: collapsedDependencyCount,
                    isExpanded: $expandedDependencies,
                )
                PackageDetailSectionDivider()
                DiscoverPackageInstallSection(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: package) { _, newPackage in
            viewModel.update(package: newPackage)
            expandedDependencies = false
        }
    }
}

private struct DiscoverPackageDetailHeroSection: View {
    let viewModel: DiscoverPackageDetailViewModel

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: BrewRadius.lg)
                    .fill(Color.brewBrandTint)
                    .frame(width: 44, height: 44)
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brewBrandPrimary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                HStack(spacing: BrewSpacing.sm) {
                    Text(viewModel.name)
                        .font(.brewTitle1)
                        .foregroundStyle(Color.brewTextPrimary)

                    Text(viewModel.packageKindChrome.badgeLabel)
                        .font(.brewCaption2)
                        .foregroundStyle(Color.brewBrandPrimary)
                        .padding(.horizontal, BrewSpacing.xs)
                        .padding(.vertical, BrewSpacing.xxs)
                        .background(Color.brewBrandTint)
                        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm))

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
}

private struct DiscoverPackageDetailMetadataSection: View {
    let viewModel: DiscoverPackageDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Details")
            detailRow(label: "Stable version", value: viewModel.stableVersionLabel)
            if viewModel.showsInstallMetrics {
                detailRow(label: "30-day installs", value: viewModel.installs30DayLabel)
            }
            if let installedVersion = viewModel.installedVersionLabel {
                detailRow(label: "Installed", value: installedVersion)
            }
            if let url = viewModel.homepageURL {
                homepageRow(url: url)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.brewCallout.weight(.medium))
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func homepageRow(url: URL) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text("Homepage")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 110, alignment: .leading)
            Link(destination: url) {
                HStack(spacing: BrewSpacing.xxs) {
                    Text(url.host ?? url.absoluteString)
                        .font(.brewCallout.weight(.medium))
                    Image(systemName: "arrow.up.right")
                        .font(.brewCaption2)
                }
                .foregroundStyle(Color.brewBrandPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, BrewSpacing.xs)
    }
}

private struct DiscoverPackageDetailDependenciesSection: View {
    let viewModel: DiscoverPackageDetailViewModel
    let collapsedCount: Int
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            PackageDetailSectionHeading(title: "Dependencies")
            let deps = viewModel.dependencyNames
            if deps.isEmpty {
                Text("No dependencies.")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                let visible = isExpanded ? deps : Array(deps.prefix(collapsedCount))
                ForEach(visible, id: \.self) { name in
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
                if deps.count > collapsedCount {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Text(isExpanded ? "Show less" : "+\(deps.count - collapsedCount) more…")
                            .font(.brewCallout)
                            .foregroundStyle(Color.brewBrandPrimary)
                    }
                    .buttonStyle(.plain)
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
                PackageDetailCommandConsole(
                    command: viewModel.installCommand,
                    summaryText: "Installs this package on your Mac",
                )
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

#Preview {
    DiscoverPackageDetailView(
        package: AppPreviewSupport.discoverPreviewPackage,
        installedRepository: AppPreviewSupport.makeInstalledPackagesRepository(),
    )
    .frame(minWidth: 380, minHeight: 480)
}
