//
//  InstalledPackageDetailSubviewSections.swift
//  Brew
//

import AppKit
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

struct InstalledPackageDetailHeroSection: View {
    let viewModel: InstalledPackageDetailViewModel

    var body: some View {
        let chrome = viewModel.packageKind.chrome
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
                    Text(viewModel.packageName)
                        .font(.brewTitle1)
                        .foregroundStyle(Color.brewTextPrimary)

                    Image(
                        systemName: viewModel.showsUpgradeAvailable ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    )
                    .font(.brewTitle3)
                    .foregroundStyle(
                        viewModel.showsUpgradeAvailable ? Color.brewStatusWarning : Color.brewStatusSuccess,
                    )
                    .accessibilityLabel(
                        viewModel.showsUpgradeAvailable ? "Update available" : "Installed",
                    )

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
                }

                if let subtitle = heroSubtitle {
                    Text(subtitle)
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
        }
    }

    private var heroSubtitle: String? {
        let trimmed = viewModel.package.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

struct InstalledPackageDetailMetadataSection: View {
    let viewModel: InstalledPackageDetailViewModel

    private let labelWidth: CGFloat = 100

    var body: some View {
        let metadata = viewModel.metadataItem
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Details")
            detailRow(
                label: "Installed",
                value: metadata.installedVersionsValue,
                valueColor: metadata.isOutdated ? .brewStatusWarning : .brewTextPrimary,
            )
            detailRow(label: "Latest stable", value: metadata.latestVersionValue)
            if let dateValue = metadata.installDateValue {
                detailRow(label: "Installed on", value: dateValue)
            }
            if let reason = metadata.installReasonValue {
                detailRow(label: "Install reason", value: reason)
            }
            if let license = metadata.licenseValue {
                detailRow(label: "License", value: license)
            }
            if let tap = metadata.tapDisplayValue {
                sourceRow(tap: tap, url: metadata.sourceURL)
            }
            if let homepageURL = metadata.homepageURL {
                homepageRow(url: homepageURL, title: metadata.homepageDisplayTitle ?? homepageURL.absoluteString)
            }
            if metadata.isPinned {
                detailRow(label: "Pinned", value: "Yes")
            }
            if metadata.isKegOnly {
                detailRow(label: "Keg-only", value: "Yes")
            }
            if let caveats = metadata.caveatsText {
                caveatsCallout(text: caveats)
            }
        }
    }

    private func detailRow(label: String, value: String, valueColor: Color = .brewTextPrimary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(.brewCallout.weight(.medium))
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

    private func homepageRow(url: URL, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text("Homepage")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Link(destination: url) {
                HStack(spacing: BrewSpacing.xxs) {
                    Text(title)
                        .font(.brewCallout.weight(.medium))
                    Image(systemName: "arrow.up.right")
                        .font(.brewCaption2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func caveatsCallout(text: String) -> some View {
        HStack(alignment: .center, spacing: BrewSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewBrandPrimary)
            Text(text)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
        }
        .padding(BrewSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewBrandTint)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }
}

struct InstalledPackageDetailDependentsSection: View {
    let viewModel: InstalledPackageDetailViewModel
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            dependentsHeading
            if viewModel.dependentRelationships.isEmpty {
                Text("No dependents.")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                InstalledPackageDetailRelationshipList(
                    relationships: viewModel.dependentRelationships,
                    dotStyle: .warning,
                    onSelectInstalledPackage: onSelectInstalledPackage,
                )
            }
        }
    }

    private var dependentsHeading: some View {
        HStack(spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Dependents")
            if let badgeTitle = viewModel.uninstallItem.usedByBlockingBadgeTitle {
                Text(badgeTitle)
                    .font(.brewCaption2.weight(.semibold))
                    .foregroundStyle(Color.brewStatusWarning)
                    .padding(.horizontal, BrewSpacing.xs)
                    .padding(.vertical, BrewSpacing.xxs)
                    .background(Color.brewStatusWarningSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm))
            }
        }
    }
}

struct UninstallBlockedCallout: View {
    let lead: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewStatusWarning)
            Text("\(Text(lead).fontWeight(.semibold)) \(bodyText)")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextPrimary)
        }
        .padding(BrewSpacing.sm)
        .background(Color.brewStatusWarningSubtle)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }
}

struct InstalledPackageDetailRelationshipList: View {
    let relationships: [PackageRelationshipItem]
    let dotStyle: PackageRelationshipDotStyle
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            if relationships.isEmpty {
                Text("None.")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                ForEach(relationships) { relationship in
                    relationshipRow(relationship)
                }
            }
        }
    }

    private func relationshipRow(_ relationship: PackageRelationshipItem) -> some View {
        let isInstalled = relationship.isInstalledInInventory
        return Button {
            if let installedPackageID = relationship.installedPackageID {
                onSelectInstalledPackage(installedPackageID)
            }
        } label: {
            HStack(spacing: BrewSpacing.sm) {
                Circle()
                    .fill(dotStyle.color)
                    .frame(width: 6, height: 6)
                Text(relationship.displayName)
                    .font(.brewCode)
                    .foregroundStyle(Color.brewTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isInstalled {
                    Image(systemName: "chevron.right")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextTertiary)
                }
            }
            .padding(.vertical, BrewSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInstalled)
        .accessibilityLabel(
            isInstalled
                ? "Open installed package \(relationship.displayName)"
                : "\(relationship.displayName), not installed",
        )
    }
}

enum PackageRelationshipDotStyle {
    case neutral
    case warning

    var color: Color {
        switch self {
        case .neutral:
            Color.brewTextTertiary
        case .warning:
            Color.brewStatusWarning
        }
    }
}
