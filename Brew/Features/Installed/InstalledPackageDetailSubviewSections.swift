//
//  InstalledPackageDetailSubviewSections.swift
//  Brew
//

import AppKit
import SwiftUI

struct InstalledPackageDetailSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.brewSubheadline.weight(.semibold))
            .foregroundStyle(Color.brewTextPrimary)
    }
}

struct InstalledPackageDetailSectionDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.brewBorderSeparator)
    }
}

struct InstalledPackageDetailHeroSection: View {
    let viewModel: InstalledDetailsViewModel

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
                    Text(viewModel.packageName)
                        .font(.brewTitle1)
                        .foregroundStyle(Color.brewTextPrimary)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.brewTitle3)
                        .foregroundStyle(Color.brewStatusSuccess)
                        .accessibilityLabel("Installed")

                    Text(viewModel.packageKind.chrome.badgeLabel)
                        .font(.brewCaption2)
                        .foregroundStyle(Color.brewBrandPrimary)
                        .padding(.horizontal, BrewSpacing.xs)
                        .padding(.vertical, BrewSpacing.xxs)
                        .background(Color.brewBrandTint)
                        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm))
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
}

struct InstalledPackageDetailMetadataSection: View {
    let package: BrewPackage

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            InstalledPackageDetailSectionHeading(title: "Details")
            detailRow(label: "Version", value: versionColumnValue(package.latestVersion))
            detailRow(label: "Installed", value: installedValue(package))
            if let homepageURL = package.homepageURL {
                homepageRow(url: homepageURL)
            }
        }
    }

    private func versionColumnValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func installedValue(_ package: BrewPackage) -> String {
        if package.installedVersions.isEmpty {
            return "—"
        }
        return package.installedVersions.joined(separator: ", ")
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 100, alignment: .leading)
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
                .frame(width: 100, alignment: .leading)
            Link(destination: url) {
                HStack(spacing: BrewSpacing.xxs) {
                    Text(homepageLinkTitle(for: url))
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

    private func homepageLinkTitle(for url: URL) -> String {
        if let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
        }
        return url.absoluteString
    }
}

struct InstalledPackageDetailUsedBySection: View {
    let viewModel: InstalledDetailsViewModel
    let collapsedRelationshipCount: Int
    let onSelectInstalledPackage: (BrewPackage.ID) -> Void
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            InstalledPackageDetailSectionHeading(title: "Used by")
            if viewModel.dependentRelationships.isEmpty {
                Text("No installed packages use this package.")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                InstalledPackageDetailRelationshipList(
                    title: "Used by",
                    relationships: viewModel.dependentRelationships,
                    dotStyle: .warning,
                    isExpanded: $isExpanded,
                    showsHeading: false,
                    collapsedRelationshipCount: collapsedRelationshipCount,
                    onSelectInstalledPackage: onSelectInstalledPackage,
                )
                if !viewModel.dependentRelationships.isEmpty {
                    usedByCallout
                }
            }
        }
    }

    private var usedByCallout: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewBrandPrimary)
            Text("Other installed packages depend on this. Removing it may break them.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextPrimary)
        }
        .padding(BrewSpacing.sm)
        .background(Color.brewBrandTint)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }
}

struct InstalledPackageDetailRelationshipList: View {
    let title: String
    let relationships: [PackageRelationshipItem]
    let dotStyle: PackageRelationshipDotStyle
    let collapsedRelationshipCount: Int
    let onSelectInstalledPackage: (BrewPackage.ID) -> Void
    let showsHeading: Bool
    @Binding var isExpanded: Bool

    init(
        title: String,
        relationships: [PackageRelationshipItem],
        dotStyle: PackageRelationshipDotStyle,
        isExpanded: Binding<Bool>,
        showsHeading: Bool = true,
        collapsedRelationshipCount: Int,
        onSelectInstalledPackage: @escaping (BrewPackage.ID) -> Void,
    ) {
        self.title = title
        self.relationships = relationships
        self.dotStyle = dotStyle
        _isExpanded = isExpanded
        self.showsHeading = showsHeading
        self.collapsedRelationshipCount = collapsedRelationshipCount
        self.onSelectInstalledPackage = onSelectInstalledPackage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            if showsHeading {
                InstalledPackageDetailSectionHeading(title: title)
            }
            if relationships.isEmpty {
                Text("No \(title.lowercased()).")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                let visibleRelationships = visibleRelationships(relationships, isExpanded: isExpanded)
                ForEach(visibleRelationships) { relationship in
                    relationshipRow(relationship)
                }
                if relationships.count > collapsedRelationshipCount {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Text(
                            isExpanded
                                ? "Show less"
                                : "+\(relationships.count - collapsedRelationshipCount) more…",
                        )
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewBrandPrimary)
                    }
                    .buttonStyle(.plain)
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

    private func visibleRelationships(
        _ relationships: [PackageRelationshipItem],
        isExpanded: Bool,
    ) -> [PackageRelationshipItem] {
        guard !isExpanded, relationships.count > collapsedRelationshipCount else {
            return relationships
        }
        return Array(relationships.prefix(collapsedRelationshipCount))
    }
}

struct InstalledPackageDetailInfoCommandSection: View {
    let title: String
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            InstalledPackageDetailSectionHeading(title: title)
            commandConsole
        }
    }

    private var commandConsole: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Terminal command", systemImage: "terminal")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    copyCommandToPasteboard(command)
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

            Text("Shows detailed information about this package")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BrewSpacing.md)
                .padding(.vertical, BrewSpacing.sm)
                .background(Color.brewSurfaceRecessed)
        }
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private func copyCommandToPasteboard(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
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
