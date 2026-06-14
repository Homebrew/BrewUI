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
    let viewModel: InstalledPackageDetailViewModel

    var body: some View {
        let metadata = viewModel.metadataItem
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Details")
            detailRow(label: "Version", value: metadata.latestVersionValue)
            detailRow(label: "Installed", value: metadata.installedVersionsValue)
            if let homepageURL = metadata.homepageURL {
                homepageRow(url: homepageURL, title: metadata.homepageDisplayTitle ?? homepageURL.absoluteString)
            }
        }
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

    private func homepageRow(url: URL, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text("Homepage")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 100, alignment: .leading)
            Link(destination: url) {
                HStack(spacing: BrewSpacing.xxs) {
                    Text(title)
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
}

struct InstalledPackageDetailUsedBySection: View {
    let viewModel: InstalledPackageDetailViewModel
    let collapsedRelationshipCount: Int
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            usedByHeading
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
            }
        }
    }

    private var usedByHeading: some View {
        HStack(spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Used by")
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

enum RelationshipRowID: Hashable {
    case relationship(HomebrewPackageID)
    case showMore
}

/// Pure helper: what rows are arrow-key navigable in a relationship list, in display order. Extracted
/// so it can be unit-tested without instantiating SwiftUI views.
func relationshipNavigableIDs(
    relationships: [PackageRelationshipItem],
    isExpanded: Bool,
    collapsedRelationshipCount: Int,
) -> [RelationshipRowID] {
    guard !relationships.isEmpty else { return [] }
    let visibleCount = isExpanded || relationships.count <= collapsedRelationshipCount
        ? relationships.count
        : collapsedRelationshipCount
    var ids = relationships.prefix(visibleCount).map { RelationshipRowID.relationship($0.id) }
    if relationships.count > collapsedRelationshipCount {
        ids.append(.showMore)
    }
    return ids
}

/// Pure helper: the row that focus should land on after a collapsed section auto-expands due to
/// Down pressed on the last visible row. Returns nil if no expansion is appropriate.
func relationshipAutoExpandTargetID(
    relationships: [PackageRelationshipItem],
    isExpanded: Bool,
    collapsedRelationshipCount: Int,
) -> RelationshipRowID? {
    guard !isExpanded, relationships.indices.contains(collapsedRelationshipCount) else {
        return nil
    }
    return .relationship(relationships[collapsedRelationshipCount].id)
}

struct InstalledPackageDetailRelationshipList: View {
    let title: String
    let relationships: [PackageRelationshipItem]
    let dotStyle: PackageRelationshipDotStyle
    let collapsedRelationshipCount: Int
    let onSelectInstalledPackage: (InstalledBrewPackage.ID) -> Void
    let showsHeading: Bool
    @Binding var isExpanded: Bool
    @FocusState private var focusedRow: RelationshipRowID?

    init(
        title: String,
        relationships: [PackageRelationshipItem],
        dotStyle: PackageRelationshipDotStyle,
        isExpanded: Binding<Bool>,
        showsHeading: Bool = true,
        collapsedRelationshipCount: Int,
        onSelectInstalledPackage: @escaping (InstalledBrewPackage.ID) -> Void,
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
                PackageDetailSectionHeading(title: title)
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
                    showMoreRow
                }
            }
        }
        .focusableListSection(
            orderedIDs: navigableIDs,
            focusedRow: $focusedRow,
            onDownPastLast: autoExpandStep,
        )
    }

    private var navigableIDs: [RelationshipRowID] {
        relationshipNavigableIDs(
            relationships: relationships,
            isExpanded: isExpanded,
            collapsedRelationshipCount: collapsedRelationshipCount,
        )
    }

    private var autoExpandStep: (() -> RelationshipRowID?)? {
        guard let targetID = relationshipAutoExpandTargetID(
            relationships: relationships,
            isExpanded: isExpanded,
            collapsedRelationshipCount: collapsedRelationshipCount,
        ) else {
            return nil
        }
        return {
            isExpanded = true
            return targetID
        }
    }

    @ViewBuilder
    private var showMoreRow: some View {
        let isFocused = focusedRow == .showMore
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
            .padding(.vertical, BrewSpacing.xxs)
            .padding(.horizontal, BrewSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(isFocused ? Color.brewBrandTint : Color.clear)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: BrewRadius.sm)
                        .strokeBorder(Color.brewBrandPrimary, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedRow, equals: .showMore)
    }

    private func relationshipRow(_ relationship: PackageRelationshipItem) -> some View {
        let isInstalled = relationship.isInstalledInInventory
        let rowID = RelationshipRowID.relationship(relationship.id)
        let isFocused = focusedRow == rowID
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
            .padding(.horizontal, BrewSpacing.xs)
            .background {
                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(isFocused ? Color.brewBrandTint : Color.clear)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: BrewRadius.sm)
                        .strokeBorder(Color.brewBrandPrimary, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInstalled)
        .focused($focusedRow, equals: rowID)
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
