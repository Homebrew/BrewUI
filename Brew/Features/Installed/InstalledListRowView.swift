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

    private var accentColor: Color {
        switch row.kind {
        case .formula:
            Color.brewBrandPrimary
        case .cask:
            Color.brewStatusInfo
        }
    }

    private var iconBackground: Color {
        switch row.kind {
        case .formula:
            Color.brewBrandTint
        case .cask:
            Color.brewStatusInfoSubtle
        }
    }

    private var badgeLabel: String {
        switch row.kind {
        case .formula:
            "FORMULA"
        case .cask:
            "CASK"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: "cube.box.fill")
                    .font(.body)
                    .foregroundStyle(accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                HStack(spacing: BrewSpacing.sm) {
                    Text(row.name)
                        .font(.brewBody)
                        .foregroundStyle(Color.brewTextPrimary)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.brewStatusSuccess)
                        .accessibilityLabel("Installed")

                    Text(badgeLabel)
                        .font(.brewCaption2)
                        .foregroundStyle(accentColor)
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

                Text(row.description)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                versionLine
            }
        }
        .padding(.vertical, BrewSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [row.name, row.description, row.installedVersion]
        if let update = row.updateVersion {
            parts.append("Update available to \(update)")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var versionLine: some View {
        if let update = row.updateVersion {
            HStack(spacing: BrewSpacing.xs) {
                Text(row.installedVersion)
                    .foregroundStyle(Color.brewTextTertiary)
                Text("→")
                    .foregroundStyle(Color.brewTextTertiary)
                Text(update)
                    .foregroundStyle(Color.brewBrandPrimary)
            }
            .font(.brewCaption)
        } else {
            Text(row.installedVersion)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
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
