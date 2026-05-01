//
//  InstalledListRowView.swift
//  Brew
//

import SwiftUI

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

struct InstalledListRowView: View {
    let row: InstalledPackageRow

    private var chrome: PackageKindChrome {
        row.kind.chrome
    }

    private var statusIconName: String {
        row.showsUpdateAvailable ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
    }

    private var statusIconColor: Color {
        row.showsUpdateAvailable ? .brewStatusWarning : .brewStatusSuccess
    }

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor(chrome.iconBackground))
                    .frame(width: 36, height: 36)
                Image(systemName: "cube.box.fill")
                    .font(.body)
                    .foregroundStyle(accentColor(chrome.accent))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                HStack(spacing: BrewSpacing.sm) {
                    Text(row.name)
                        .font(.brewBody)
                        .foregroundStyle(Color.brewTextPrimary)

                    Image(systemName: statusIconName)
                        .font(.body)
                        .foregroundStyle(statusIconColor)
                        .accessibilityHidden(true)

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

                    Spacer(minLength: 0)
                }

                if row.hasDescription {
                    Text(row.description)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                versionLine
            }
        }
        .padding(.vertical, BrewSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.listRowAccessibilitySummary)
    }

    @ViewBuilder
    private var versionLine: some View {
        switch row.versionPresentation {
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

#Preview("Formula with update") {
    InstalledListRowView(
        row: InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "Distributed revision control system",
            installedVersion: "v2.45.0",
            updateVersion: "v2.45.1",
        ),
    )
    .padding()
    .frame(width: 400)
}

#Preview("Cask") {
    InstalledListRowView(
        row: InstalledPackageRow(
            name: "Docker",
            kind: .cask,
            description: "App to build and share containerized applications",
            installedVersion: "v4.39.0",
        ),
    )
    .padding()
    .frame(width: 400)
}
