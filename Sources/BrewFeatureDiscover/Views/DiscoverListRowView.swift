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
            showsInstallMetrics: showsInstallMetrics,
        )
        .id(discoveryPackage.id)
    }
}

struct DiscoverListRowView: View {
    let discoveryPackage: DiscoveryBrewPackage
    @State private var viewModel: DiscoverListRowViewModel

    init(
        discoveryPackage: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
        brewCommandCenter: any BrewCommandCenter,
        showsInstallMetrics: Bool = true,
    ) {
        self.discoveryPackage = discoveryPackage
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
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            iconBadge
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
        }
        .padding(.vertical, BrewSpacing.sm)
        .task(id: discoveryPackage.id) {
            await viewModel.observeRowUpdates()
        }
        .onChange(of: discoveryPackage) { _, new in
            viewModel.update(discoveryPackage: new)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.rowAccessibilityLabel)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor(viewModel.packageKindChrome.iconBackground))
                .frame(width: 36, height: 36)
            Image(systemName: "shippingbox.fill")
                .font(.body)
                .foregroundStyle(accentColor(viewModel.packageKindChrome.accent))
        }
        .accessibilityHidden(true)
    }

    private var titleRow: some View {
        HStack(spacing: BrewSpacing.sm) {
            Text(viewModel.name)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)

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
    }

    private var metadataRow: some View {
        HStack(spacing: BrewSpacing.sm) {
            Text("v\(viewModel.stableVersionLabel)")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
            if viewModel.showsInstallMetrics {
                Text("•")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
                Text("\(viewModel.installs30DayLabel) installs (30d)")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func accentColor(_ token: PackageKindAccentToken) -> Color {
        switch token {
        case .brandPrimary:
            Color.brewBrandPrimary
        case .statusInfo:
            Color.brewStatusInfo
        }
    }

    private func iconBackgroundColor(_ token: PackageKindIconBackgroundToken) -> Color {
        switch token {
        case .brandTint:
            Color.brewBrandTint
        case .statusInfoSubtle:
            Color.brewStatusInfoSubtle
        }
    }
}

#if DEBUG
    import BrewRepositoriesTestSupport

    #Preview("Installed") {
        DiscoverListRowView(
            discoveryPackage: AppPreviewSupport.discoverPreviewPackage,
            installedRepository: AppPreviewSupport.makeInstalledPackagesRepository(),
            brewCommandCenter: AppPreviewSupport.commandCenter,
        )
        .padding()
        .frame(width: 440)
    }
#endif
