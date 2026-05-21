import AppKit
import SwiftUI

/// Right-hand column: detail for the selected discover package.
struct DiscoverPackageDetailView: View {
    @Bindable var viewModel: DiscoverPackageDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                hero
                metadata
                installShell
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: BrewSpacing.sm) {
            Text(viewModel.name)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)

            Text(viewModel.packageKindChrome.badgeLabel)
                .font(.brewCaption2)
                .foregroundStyle(accentColor(viewModel.packageKindChrome.accent))
                .padding(.horizontal, BrewSpacing.xs)
                .padding(.vertical, BrewSpacing.xxs)
                .background {
                    Capsule().fill(Color.brewSurfaceElevated)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
                }

            if viewModel.isInstalled {
                DiscoverInstalledBadge()
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            metadataRow(title: "Stable version", value: viewModel.stableVersionLabel)
            metadataRow(title: "Installs (30d)", value: viewModel.installs30DayLabel)
            if let installedVersionLabel = viewModel.installedVersionLabel {
                metadataRow(title: "Installed version", value: installedVersionLabel)
            }
            if let homepageURL = viewModel.homepageURL {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text("Homepage")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextTertiary)
                    Link(homepageURL.absoluteString, destination: homepageURL)
                        .font(.brewBody)
                        .foregroundStyle(Color.brewTextLink)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var installShell: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Divider()
            Text("Install")
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(Color.brewTextPrimary)
            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                DiscoverInstallCommandShell(command: viewModel.installCommand)

                Button {
                    // UI-only for this slice; command execution wiring comes later.
                } label: {
                    Text(viewModel.isInstalled ? "Installed" : "Install")
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)

                Text("Install actions are UI-only in this iteration.")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
            }
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            Text(title)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
            Text(value)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)
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
}

private struct DiscoverInstallCommandShell: View {
    let command: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Terminal command", systemImage: "terminal")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.sm)
            .background(Color.brewSurfaceRecessed)

            Text(command)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .textSelection(.enabled)
        }
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
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
    let row = DiscoverListRowViewModel(
        discoveryPackage: DiscoveryBrewPackage(
            package: AppPreviewSupport.discoverFormulaeCatalogue.first ?? BrewPackage(
                name: "git",
                displayName: "git",
                kind: .formula,
                description: "Distributed revision control system",
                homepage: "https://git-scm.com",
                latestVersion: "2.46.1",
                dependencies: [],
            ),
            thirtyDayInstallCount: 420_000,
        ),
        installedPackage: AppPreviewSupport.outdatedFormula,
    )
    DiscoverPackageDetailView(viewModel: DiscoverPackageDetailViewModel(row: row))
        .frame(minWidth: 380, minHeight: 480)
}
