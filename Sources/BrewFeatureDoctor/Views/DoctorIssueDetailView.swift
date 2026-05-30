//
//  DoctorIssueDetailView.swift
//  BrewFeatureDoctor
//

import AppKit
import BrewCore
import BrewUIComponents
import SwiftUI

/// Right-hand column: full detail for the selected `brew doctor` issue.
///
/// Sectioned per `.ai/plans/DoctorParsing-Plan.md`: title + severity / What this means + inline chips /
/// Affected / Suggested fix sequences (each rendered as a ``CommandBlockView`` with an admin hint when
/// any step needs `sudo`) / Links split action vs reference / Raw output as the verbatim fallback.
struct DoctorIssueDetailView: View {
    @Bindable var viewModel: DoctorViewModel
    let item: DoctorIssueItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                heroSection
                if !item.details.isEmpty || !item.inlineChips.isEmpty {
                    detailsSection
                }
                if !item.affectedItems.isEmpty {
                    affectedSection
                }
                if !item.fixSequences.isEmpty {
                    fixSection
                }
                if !item.links.isEmpty {
                    linksSection
                }
                if !item.rawBody.isEmpty {
                    rawOutputSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            DoctorSeverityBadge(severity: item.severity)
            Text(item.title)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
        }
    }

    // MARK: - What this means

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "What this means")
            if !item.details.isEmpty {
                Text(item.details)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
            }
            if !item.inlineChips.isEmpty {
                chipsRow
            }
        }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrewSpacing.xs) {
                ForEach(item.inlineChips) { chip in
                    DoctorChipButton(chip: chip)
                }
            }
        }
    }

    // MARK: - Affected

    private var affectedSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Affected")
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(item.affectedItems, id: \.self) { affected in
                    Text(affected)
                        .font(.brewCode)
                        .foregroundStyle(Color.brewTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Suggested fix

    private var fixSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            PackageDetailSectionHeading(title: "Suggested fix")
            ForEach(item.fixSequences) { sequence in
                sequenceCard(sequence)
            }
            if let primary = item.primaryRunnableSequence, sequenceIsPrimary(primary) {
                runFixControls
            }
        }
    }

    private func sequenceIsPrimary(_ sequence: DoctorFixSequence) -> Bool {
        item.primaryRunnableSequence?.id == sequence.id
    }

    private func sequenceCard(_ sequence: DoctorFixSequence) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            if sequence.steps.contains(where: \.needsAdmin) {
                Label("Needs admin · runs in Terminal", systemImage: "lock.fill")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
            }
            CommandBlockView(commands: sequence.steps.map(\.displayCommand))
        }
    }

    private var runFixControls: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Button {
                viewModel.runFix(for: item)
            } label: {
                if viewModel.isFixRunning(item) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 120)
                } else {
                    Text("Run Fix")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isFixRunning(item))
            .accessibilityLabel("Run Fix")

            if let fixError = viewModel.fixError(item) {
                Text(fixError)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewStatusError)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Links")
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(item.links) { link in
                    DoctorLinkRow(link: link)
                }
            }
        }
    }

    // MARK: - Raw output

    private var rawOutputSection: some View {
        DisclosureGroup {
            Text(item.rawBody)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
                .textSelection(.enabled)
                .padding(.top, BrewSpacing.sm)
        } label: {
            Text("Raw output")
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(Color.brewTextPrimary)
        }
    }
}

/// Severity pill rendered next to the issue title. Uses the design-system status tokens; the
/// row-level Homebrew warning glyph stays brand-amber regardless of severity.
private struct DoctorSeverityBadge: View {
    let severity: DoctorSeverity

    var body: some View {
        Label(label, systemImage: icon)
            .font(.brewCaption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
            .background(background, in: Capsule())
            .accessibilityLabel("Severity: \(label)")
    }

    private var label: String {
        switch severity {
        case .info: "Info"
        case .caution: "Caution"
        case .danger: "Danger"
        case .unsupported: "Unsupported"
        }
    }

    private var icon: String {
        switch severity {
        case .info: "info.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .danger, .unsupported: "xmark.octagon.fill"
        }
    }

    private var foreground: Color {
        switch severity {
        case .info: .brewStatusInfo
        case .caution: .brewStatusWarning
        case .danger, .unsupported: .brewStatusError
        }
    }

    private var background: Color {
        switch severity {
        case .info: .brewStatusInfoSubtle
        case .caution: .brewStatusWarningSubtle
        case .danger, .unsupported: .brewStatusErrorSubtle
        }
    }
}

/// Copyable inline chip — clicking copies the command to the pasteboard.
private struct DoctorChipButton: View {
    let chip: DoctorBacktickChip

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(chip.displayCommand, forType: .string)
        } label: {
            HStack(spacing: BrewSpacing.xxs) {
                Image(systemName: "doc.on.doc")
                    .imageScale(.small)
                Text(chip.displayCommand)
                    .font(.brewCodeSmall)
            }
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
            .foregroundStyle(Color.brewTextPrimary)
            .background(Color.brewSurfaceRecessed, in: Capsule())
            .overlay(Capsule().stroke(Color.brewBorderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy \(chip.displayCommand)")
    }
}

/// One link row. Action links are prominent with a download glyph; reference links are muted.
private struct DoctorLinkRow: View {
    let link: DoctorLink

    var body: some View {
        switch link.role {
        case .action:
            Link(destination: link.url) {
                Label(link.url.absoluteString, systemImage: "arrow.up.right.square.fill")
                    .font(.brewCallout.weight(.semibold))
            }
            .foregroundStyle(Color.brewBrandPrimary)
        case .reference:
            Link(destination: link.url) {
                Label(link.url.absoluteString, systemImage: "doc.text")
                    .font(.brewCallout)
            }
            .foregroundStyle(Color.brewTextLink)
        }
    }
}

/// Placeholder shown in the detail column when no issue is selected (initial loading or healthy).
struct DoctorDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Run diagnostics, then choose an issue to see details and fixes.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview("Doctor issue detail") {
        let report = PreviewSupport.doctorReport
        let viewModel = makeDoctorPreviewViewModel(report: report)
        Group {
            if let issue = report.issues.first {
                DoctorIssueDetailView(viewModel: viewModel, item: DoctorIssueItem(id: 0, issue: issue))
            }
        }
        .frame(width: 380, height: 600)
    }
#endif
