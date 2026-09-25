import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Owns one Discover row's view model, reading the shared installed-status source from the environment at
/// the row boundary so the installed badge stays reactive without threading the repository through parents.
struct DiscoverListRowRoot: View {
    let discoveryPackage: DiscoveryBrewPackage
    let showsInstallMetrics: Bool
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter

    var body: some View {
        DiscoverListRowView(
            discoveryPackage: discoveryPackage,
            installedRepository: installedPackagesRepository,
            brewCommandCenter: brewCommandCenter,
            fetchRevision: installedPackagesRepository.fetchRevision,
            showsInstallMetrics: showsInstallMetrics,
        )
        .id(discoveryPackage.id)
    }
}

struct DiscoverListRowView: View {
    let discoveryPackage: DiscoveryBrewPackage
    /// Settled inventory fetches, fed from the environment by ``DiscoverListRowRoot`` (`0` in
    /// previews). A change releases the install busy bridge when the reconcile settled without
    /// the package becoming installed.
    let fetchRevision: Int
    @State private var viewModel: DiscoverListRowViewModel

    init(
        discoveryPackage: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
        brewCommandCenter: any BrewCommandCenter,
        fetchRevision: Int = 0,
        showsInstallMetrics: Bool = true,
    ) {
        self.discoveryPackage = discoveryPackage
        self.fetchRevision = fetchRevision
        _viewModel = State(
            initialValue: DiscoverListRowViewModel(
                discoveryPackage: discoveryPackage,
                installedRepository: installedRepository,
                brewCommandCenter: brewCommandCenter,
                showsInstallMetrics: showsInstallMetrics,
            ),
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            titleRow
            if viewModel.hasDescription {
                Text(viewModel.descriptionText)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            metadataRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BrewSpacing.sm)
        .task(id: discoveryPackage.id) {
            await viewModel.observeRowUpdates()
        }
        .onChange(of: discoveryPackage) { _, new in
            viewModel.update(discoveryPackage: new)
        }
        .onChange(of: fetchRevision) {
            viewModel.releaseLatchedOperationState()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.rowAccessibilityLabel)
    }

    private var titleRow: some View {
        HStack(spacing: BrewSpacing.sm) {
            Text(viewModel.name)
                .font(.brewBodyEmphasized)
                .foregroundStyle(Color.brewTextPrimary)
                .lineLimit(1)

            if viewModel.showsInstallBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }

            packageKindBadge

            if viewModel.installedStatusLabel != nil {
                DiscoverInstalledBadge()
            }

            Spacer(minLength: 0)
        }
    }

    private var packageKindBadge: some View {
        Text(viewModel.packageKindChrome.badgeLabel)
            .font(.brewCaption2)
            .foregroundStyle(accentColor(viewModel.packageKindChrome.accent))
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xs)
            .background {
                Capsule()
                    .fill(Color.brewSurfaceElevated)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
                    }
                    .brewHiddenWhenRedacted()
            }
    }

    private var metadataRow: some View {
        HStack(spacing: BrewSpacing.sm) {
            Text(verbatim: "v\(viewModel.stableVersionLabel)")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
            if viewModel.showsInstallMetrics {
                Text(verbatim: "•")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
                Text("\(viewModel.installs30DayLabel) installs (30d)", bundle: #bundle, comment: "Discover row: 30-day install count; %@ is a formatted number")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func accentColor(_ token: PackageKindAccentToken) -> Color {
        switch token {
        case .brandPrimary:
            Color.brewTextBrand
        case .statusInfo:
            Color.brewStatusInfo
        }
    }
}

#if DEBUG

    #Preview("Installed") {
        DiscoverListRowView(
            discoveryPackage: PreviewSupport.discoverPreviewPackage,
            installedRepository: PreviewSupport.makeInstalledPackagesRepository(),
            brewCommandCenter: PreviewSupport.commandCenter,
        )
        .padding()
        .frame(width: 440)
    }
#endif
