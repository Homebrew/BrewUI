//
//  InstalledListRowView.swift
//  Brew
//

import SwiftUI

/// Owns ``InstalledListRowViewModel`` for one row and runs ``InstalledListRowViewModel/observeRowUpdates()`` while the row is on screen.
struct InstalledListRowRoot: View {
    let package: BrewPackage
    @Environment(\.brewCommandCenter) private var brewCommandCenter

    var body: some View {
        InstalledListRowView(
            package: package,
            brewCommandCenter: brewCommandCenter,
        )
        .id(package.id)
    }
}

struct InstalledListRowView: View {
    let package: BrewPackage
    @State private var viewModel: InstalledListRowViewModel

    init(package: BrewPackage, brewCommandCenter: BrewCommandCenter) {
        _viewModel = State(
            initialValue: InstalledListRowViewModel(
                package: package,
                brewCommandCenter: brewCommandCenter,
            ),
        )
        self.package = package
    }

    var body: some View {
        Group {
            rowContent(viewModel: viewModel)
        }
        .task(id: package.id) {
            await viewModel.observeRowUpdates()
        }
        .onChange(of: package) { _, new in
            viewModel.update(package: new)
        }
    }

    private func rowContent(viewModel: InstalledListRowViewModel) -> some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            iconBadge(viewModel: viewModel)
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                titleRow(viewModel: viewModel)
                if viewModel.hasDescription {
                    Text(viewModel.descriptionText)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                versionLine(viewModel: viewModel)
            }
        }
        .padding(.vertical, BrewSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(listAccessibilityLabel(viewModel: viewModel))
    }

    private func iconBadge(viewModel: InstalledListRowViewModel) -> some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor(viewModel.kind.chrome.iconBackground))
                .frame(width: 36, height: 36)
            Image(systemName: "cube.box.fill")
                .font(.body)
                .foregroundStyle(accentColor(viewModel.kind.chrome.accent))
        }
        .accessibilityHidden(true)
    }

    private func titleRow(viewModel: InstalledListRowViewModel) -> some View {
        HStack(spacing: BrewSpacing.sm) {
            Text(viewModel.name)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)

            if viewModel.showsUpgradeBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }

            Image(systemName: statusIconName(viewModel: viewModel))
                .font(.body)
                .foregroundStyle(statusIconColor(viewModel: viewModel))
                .accessibilityHidden(true)

            Text(viewModel.kind.chrome.badgeLabel)
                .font(.brewCaption2)
                .foregroundStyle(accentColor(viewModel.kind.chrome.accent))
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

            Spacer(minLength: 0)
        }
    }

    private func statusIconName(viewModel: InstalledListRowViewModel) -> String {
        viewModel.showsUpdateAvailable ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
    }

    private func statusIconColor(viewModel: InstalledListRowViewModel) -> Color {
        viewModel.showsUpdateAvailable ? .brewStatusWarning : .brewStatusSuccess
    }

    private func listAccessibilityLabel(viewModel: InstalledListRowViewModel) -> String {
        if viewModel.showsUpgradeBusy {
            let upgrading = String(localized: "Upgrading", comment: "VoiceOver: package upgrading")
            return "\(viewModel.accessibilitySummary), \(upgrading)"
        }
        return viewModel.accessibilitySummary
    }

    @ViewBuilder
    private func versionLine(viewModel: InstalledListRowViewModel) -> some View {
        switch viewModel.versionPresentation {
        case let .installed(version):
            Text(version)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
        case let .upgrade(current, latest):
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.xs) {
                Text(current)
                    .foregroundStyle(Color.brewTextTertiary)
                Text("→")
                    .foregroundStyle(Color.brewTextTertiary)
                Text(latest)
                    .foregroundStyle(Color.brewBrandPrimary)
            }
            .font(.brewCaption)
            .fixedSize(horizontal: false, vertical: true)
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

struct InstalledSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        Text("\(title) (\(count))")
            .font(.brewCaption2)
            .foregroundStyle(Color.brewTextTertiary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Formula with update") {
    InstalledListRowView(
        package: BrewPackage(
            name: "git",
            kind: .formula,
            description: "Distributed revision control system",
            homepage: "https://git-scm.com",
            latestVersion: "2.45.1",
            installedVersions: ["2.45.0"],
            dependencies: [],
            outdated: true,
        ),
        brewCommandCenter: NoopBrewCommandCenter.preview(),
    )
    .padding()
    .frame(width: 400)
}

#Preview("Cask") {
    InstalledListRowView(
        package: BrewPackage(
            name: "docker",
            kind: .cask,
            description: "App to build and share containerized applications",
            homepage: "https://www.docker.com",
            latestVersion: "4.39.0",
            installedVersions: ["4.39.0"],
            dependencies: [],
            outdated: false,
        ),
        brewCommandCenter: NoopBrewCommandCenter.preview(),
    )
    .padding()
    .frame(width: 400)
}
