//
//  InstalledPackageDetailSubviewSections.swift
//  Brew
//

import AppKit
import BrewCore
import BrewUIComponents
import SwiftUI

struct InstalledPackageDetailHeroSection: View {
    let viewModel: InstalledPackageDetailViewModel

    var body: some View {
        let chrome = viewModel.packageKind.chrome
        HStack(alignment: .center, spacing: BrewSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: BrewRadius.lg)
                    .strokeBorder(accentColor(chrome.accent), lineWidth: 1)
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

                    Text(chrome.badgeLabel)
                        .font(.brewCaption2)
                        .foregroundStyle(accentColor(chrome.accent))
                        .padding(.horizontal, BrewSpacing.sm)
                        .padding(.vertical, BrewSpacing.xs)
                        .background {
                            Capsule()
                                .fill(Color.brewSurfaceElevated)
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
                        }

                    statusBadge
                }

                if let subtitle = heroSubtitle {
                    Text(subtitle)
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.showsUpgradeAvailable {
            InstalledOutdatedBadge()
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewStatusSuccess)
                .accessibilityLabel(String(localized: "Installed", bundle: #bundle, comment: "VoiceOver: package is installed"))
        }
    }

    private var heroSubtitle: String? {
        let trimmed = viewModel.package.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func accentColor(_ token: PackageKindAccentToken) -> Color {
        switch token {
        case .brandPrimary: Color.brewTextBrand
        case .statusInfo: Color.brewStatusInfo
        }
    }
}

struct InstalledPackageDetailMetadataSection: View {
    let viewModel: InstalledPackageDetailViewModel

    private let labelWidth: CGFloat = 100
    private let yes = String(localized: "Yes", bundle: #bundle, comment: "Package detail value for a true flag")

    var body: some View {
        let metadata = viewModel.metadataItem
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: String(localized: "Details", bundle: #bundle, comment: "Package detail section heading"))
            detailRow(
                label: String(localized: "Installed", bundle: #bundle, comment: "Package detail row: installed version(s)"),
                value: metadata.installedVersionsValue,
                valueColor: metadata.isOutdated ? .brewStatusWarning : .brewTextPrimary,
                valueFontWeight: .heavy,
            )
            detailRow(label: String(localized: "Latest version", bundle: #bundle, comment: "Package detail row"), value: metadata.latestVersionValue)
            if let dateValue = metadata.installDateValue {
                detailRow(label: String(localized: "Installed on", bundle: #bundle, comment: "Package detail row: install date"), value: dateValue)
            }
            if let reason = metadata.installReasonValue {
                detailRow(label: String(localized: "Install reason", bundle: #bundle, comment: "Package detail row: on request or as a dependency"), value: reason)
            }
            if let license = metadata.licenseValue {
                detailRow(label: String(localized: "License", bundle: #bundle, comment: "Package detail row"), value: license)
            }
            if let tap = metadata.tapDisplayValue {
                sourceRow(tap: tap, url: metadata.sourceURL)
            }
            if let homepageURL = metadata.homepageURL {
                homepageRow(url: homepageURL, title: metadata.homepageDisplayTitle ?? homepageURL.absoluteString)
            }
            if metadata.isPinned {
                detailRow(label: String(localized: "Pinned", bundle: #bundle, comment: "Package detail row: brew pin"), value: yes)
            }
            if metadata.isKegOnly {
                detailRow(label: String(localized: "Keg-only", bundle: #bundle, comment: "Package detail row: formula is keg-only"), value: yes)
            }
            if let caveats = metadata.caveatsText {
                caveatsCallout(text: caveats)
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
            Text("Source", bundle: #bundle, comment: "Package detail row: source tap")
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
            Text("Homepage", bundle: #bundle, comment: "Package detail row: homepage link")
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
        NoteCallout(text)
            .padding(.top, BrewSpacing.lg)
    }
}

struct InstalledPackageDetailDependentsSection: View {
    let viewModel: InstalledPackageDetailViewModel
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            dependentsHeading
            if viewModel.dependentRelationships.isEmpty {
                Text("No dependents.", bundle: #bundle, comment: "Package detail: nothing depends on this package")
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
            PackageDetailSectionHeading(title: String(localized: "Dependents", bundle: #bundle, comment: "Package detail section heading: packages that depend on this one"))
            if let badgeTitle = viewModel.uninstallItem.usedByBlockingBadgeTitle {
                Text(badgeTitle)
                    .font(.brewCaption2.weight(.semibold))
                    .foregroundStyle(Color.brewTextOnBrand)
                    .padding(.horizontal, BrewSpacing.xs)
                    .padding(.vertical, BrewSpacing.xxs)
                    .background(Color.brewStatusWarningBold)
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
                .brewWarningGlyphStyle()
                .font(.brewSubheadline)
            (Text(lead).fontWeight(.semibold) + Text(verbatim: " ") + Text(bodyText))
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
                Text("None.", bundle: #bundle, comment: "Package detail: empty relationship list")
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
                ? String(
                    localized: "Open installed package \(relationship.displayName)",
                    bundle: #bundle,
                    comment: "VoiceOver: dependency row that jumps to that package; %@ is its name",
                )
                : String(
                    localized: "\(relationship.displayName), not installed",
                    bundle: #bundle,
                    comment: "VoiceOver: dependency row for a package that is not installed; %@ is its name",
                ),
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
            Color.brewStatusWarningBold
        }
    }
}
