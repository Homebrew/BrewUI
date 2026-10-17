//
//  SecurityView.swift
//  BrewFeatureSecurity
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Middle column of the Security surface: a header, then the first scan, a clean result, the affected
/// formulae, or an error. A re-scan keeps the prior content on screen with a spinner in the header.
struct SecurityView: View {
    @Bindable var viewModel: SecurityViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let note = viewModel.scanNote {
                NoteCallout(verbatim: note, tone: .info)
                    .padding(.horizontal, BrewSpacing.lg)
                    .padding(.bottom, BrewSpacing.sm)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .accessibilityElement(children: .contain)
        .axid(.securityScreen)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Security", bundle: #bundle, comment: "Security tab heading")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.subtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
                if let lastScannedAt = viewModel.lastScannedAt {
                    LastUpdatedLabel(lead: LocalizedStringResource(
                        "Last scanned",
                        bundle: #bundle,
                        comment: "Security header: lead-in before a relative time, e.g. “Last scanned 5 minutes ago”",
                    ), date: lastScannedAt)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            headerControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityHeading(.h1)
    }

    @ViewBuilder
    private var headerControls: some View {
        if viewModel.showsHeaderControls {
            HStack(spacing: BrewSpacing.sm) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(String(localized: "Re-scanning", bundle: #bundle, comment: "VoiceOver: Security re-scan spinner"))
                }
                Button(String(localized: "Scan Again", bundle: #bundle, comment: "Security header: re-run brew vulns")) {
                    Task { await viewModel.load(forceRefresh: true) }
                }
                .controlSize(.small)
                .disabled(viewModel.isRefreshing)
                .axid(.securityRescanButton)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var content: some View {
        AsyncContentView(
            state: viewModel.state,
            onRetry: { Task { await viewModel.load(forceRefresh: true) } },
            loaded: { report in
                let items = report.affectedPackages.map(SecurityPackageItem.init(package:))
                if items.isEmpty {
                    cleanState
                } else {
                    packageList(items: items)
                }
            },
        )
    }

    private var cleanState: some View {
        VStack(spacing: BrewSpacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brewStatusSuccess)
                .accessibilityHidden(true)
            Text("No known vulnerabilities", bundle: #bundle, comment: "Security clean state title")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text(
                "brew vulns found no open advisories for your installed formulae. A scan can only find advisories that have been published.",
                bundle: #bundle,
                comment: "Security clean state body",
            )
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(BrewSpacing.xl)
        .accessibilityElement(children: .combine)
        .axid(.securityCleanState)
    }

    private func packageList(items: [SecurityPackageItem]) -> some View {
        List {
            ForEach(items) { item in
                SecurityPackageRowView(item: item)
                    .id(item.id)
                    .contentShape(Rectangle())
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: BrewRadius.lg, style: .continuous)
                            .fill(viewModel.selectedPackageID == item.id ? Color.brewBrandTint : Color.clear)
                            .padding(.horizontal, BrewSpacing.sm),
                    )
                    .onTapGesture {
                        viewModel.setSelection(item.id)
                    }
                    .axid(.securityRow(token: item.name))
            }
        }
        .task(id: viewModel.shouldFocusList) {
            isFocused = viewModel.shouldFocusList
        }
        .focused($isFocused)
        .listStyle(.inset)
        .accessibilityLabel(String(localized: "Formulae with advisories", bundle: #bundle, comment: "VoiceOver: the Security list"))
        .axid(.securityList)
        .onKeyPress(.upArrow) {
            viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNext()
            return .handled
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            if let coverage = viewModel.coverageSummary {
                Text(coverage)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(
                "Scans send each formula’s source repository and version to OSV.dev.",
                bundle: #bundle,
                comment: "Security footer: what a brew vulns scan shares with the OSV service",
            )
            .font(.brewCaption)
            .foregroundStyle(Color.brewTextTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview("Security - findings") {
        SecurityView(viewModel: SecurityViewModel(repository: PreviewSupport.makeSecurityAdvisoryRepository()))
            .frame(width: 420, height: 520)
    }

    #Preview("Security - clean") {
        SecurityView(viewModel: SecurityViewModel(repository: PreviewSupport.makeSecurityAdvisoryRepository(
            report: PreviewSupport.cleanSecurityAdvisoryReport,
        )))
        .frame(width: 420, height: 520)
    }
#endif
