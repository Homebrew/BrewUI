import SwiftUI

struct DiscoverListRowView: View {
    let viewModel: DiscoverListRowViewModel

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
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
            Text("•")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
            Text("\(viewModel.installs30DayLabel) installs (30d)")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
            Spacer(minLength: 0)
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            viewModel.name,
            viewModel.packageKindChrome.badgeLabel,
            "\(viewModel.installs30DayLabel) installs in 30 days",
        ]
        if let installedStatusLabel = viewModel.installedStatusLabel {
            parts.append(installedStatusLabel)
        }
        return parts.joined(separator: ", ")
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

#Preview("Installed") {
    let previewPackage = AppPreviewSupport.discoverFormulaeCatalogue.first ?? BrewPackage(
        name: "git",
        displayName: "git",
        kind: .formula,
        description: "Distributed revision control system",
        homepage: "https://git-scm.com",
        latestVersion: "2.46.1",
        dependencies: [],
    )
    DiscoverListRowView(
        viewModel: DiscoverListRowViewModel(
            discoveryPackage: DiscoveryBrewPackage(
                package: previewPackage,
                thirtyDayInstallCount: 420_000,
            ),
            installedRepository: AppPreviewSupport.makeInstalledPackagesRepository(),
        ),
    )
    .padding()
    .frame(width: 440)
}
