//
//  SecurityPackageDetailView.swift
//  BrewFeatureSecurity
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Right-hand column: every open advisory for the selected formula, most severe first.
struct SecurityPackageDetailView: View {
    let item: SecurityPackageItem
    let showInInstalled: @MainActor (HomebrewPackageID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                hero
                ForEach(item.advisories) { advisory in
                    SecurityAdvisoryCard(advisory: advisory)
                }
                if !item.resolvedByPatchIDs.isEmpty {
                    resolvedByPatchSection
                }
            }
            .padding(BrewSpacing.xl)
            .brewPaneContentWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            AdvisorySeverityBadge(severity: item.highestSeverity)
            Text(verbatim: item.name)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
            Text(item.versionText)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            if let sourceRepository = item.sourceRepository {
                Link(destination: sourceRepository) {
                    Label(sourceRepository.absoluteString, systemImage: "link")
                        .font(.brewCallout)
                }
            }
            Button(String(localized: "Show in Installed", bundle: #bundle, comment: "Security detail: open the formula in the Installed tab, where it can be upgraded")) {
                showInInstalled(item.id)
            }
            .controlSize(.small)
            .padding(.top, BrewSpacing.xs)
        }
    }

    private var resolvedByPatchSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Already patched by Homebrew", bundle: #bundle, comment: "Security detail heading: advisories a formula patch resolves")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text(
                "These match the upstream version, but the formula applies a patch that fixes them.",
                bundle: #bundle,
                comment: "Security detail: explains advisories resolved by a formula patch",
            )
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextSecondary)
            ForEach(item.resolvedByPatchIDs, id: \.self) { id in
                Text(verbatim: id)
                    .font(.brewCode)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
            }
        }
    }
}

/// One advisory: severity, identifier link, summary and where it is fixed.
private struct SecurityAdvisoryCard: View {
    let advisory: SecurityAdvisoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
                Text(verbatim: advisory.id)
                    .font(.brewCodeBold)
                    .foregroundStyle(Color.brewTextPrimary)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                AdvisorySeverityBadge(severity: advisory.severity)
            }
            if let summary = advisory.summary {
                Text(verbatim: summary)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
            }
            if !advisory.aliases.isEmpty {
                Text(verbatim: advisory.aliases.joined(separator: ", "))
                    .font(.brewCodeSmall)
                    .foregroundStyle(Color.brewTextTertiary)
                    .textSelection(.enabled)
            }
            Label(advisory.fixDescription, systemImage: advisory.hasReleasedFix ? "checkmark.circle" : "clock")
                .font(.brewCallout)
                .foregroundStyle(advisory.hasReleasedFix ? Color.brewStatusSuccess : Color.brewTextSecondary)
            if !advisory.shortFixCommits.isEmpty {
                Text(verbatim: advisory.shortFixCommits.joined(separator: ", "))
                    .font(.brewCodeSmall)
                    .foregroundStyle(Color.brewTextTertiary)
                    .textSelection(.enabled)
            }
            if let url = advisory.advisoryURL {
                Link(destination: url) {
                    Label(url.absoluteString, systemImage: "arrow.up.right.square")
                        .font(.brewCallout)
                }
            }
        }
        .padding(BrewSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewSurfaceElevated, in: RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous)
                .strokeBorder(Color.brewBorderDefault),
        )
        .accessibilityElement(children: .contain)
        .axid(.securityAdvisory(id: advisory.id))
    }
}

/// Placeholder shown in the detail column when nothing is selected.
struct SecurityDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection", bundle: #bundle, comment: "Security detail placeholder title when nothing is selected")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Choose a formula to see its advisories and fixes.", bundle: #bundle, comment: "Security detail placeholder body when nothing is selected")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
        .brewPaneContentWidth()
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview("Security package detail") {
        Group {
            if let package = PreviewSupport.securityAdvisoryReport.affectedPackages.first {
                SecurityPackageDetailView(item: SecurityPackageItem(package: package), showInInstalled: { _ in })
            }
        }
        .frame(width: 400, height: 640)
    }
#endif
