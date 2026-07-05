//
//  DoctorIssueDetailView.swift
//  BrewFeatureDoctor
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Right-hand column: full detail for the selected `brew doctor` issue.
///
/// Walks the parsed blocks in **document order** with no section headings. Prose paragraphs render as
/// plain text; a non-prose block's colon caption (e.g. `If that doesn't show you any updates, run:`)
/// renders as a prose line right above its UI element (a ``CommandBlockView``, an items list, or link
/// rows). The reading flow matches what brew printed. Raw output stays at the bottom as the
/// never-wrong fallback.
struct DoctorIssueDetailView: View {
    @Bindable var viewModel: DoctorViewModel
    let item: DoctorIssueItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                    ForEach(Array(item.blocks.enumerated()), id: \.element.id) { index, block in
                        blockView(block)
                            .padding(.top, topPadding(for: block, isFirst: index == 0))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !item.rawBody.isEmpty {
                    Divider()
                    rawOutputSection
                }
            }
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Two-tier inter-block gap so the detail view shows the line-break vs blank-line distinction brew
    /// doctor wrote in its raw output. The first body block keeps the existing hero→content gap.
    private func topPadding(for block: DoctorBlock, isFirst: Bool) -> CGFloat {
        if isFirst {
            return BrewSpacing.lg
        }
        return block.precededByBlankLine ? BrewSpacing.lg : BrewSpacing.sm
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

    // MARK: - Blocks

    @ViewBuilder
    private func blockView(_ block: DoctorBlock) -> some View {
        switch block.content {
        case let .prose(lines):
            proseView(lines: lines)
        case let .command(steps):
            commandView(block: block, steps: steps)
        case let .data(items):
            dataView(caption: block.caption, items: items)
        case let .link(links):
            linkView(caption: block.caption, links: links)
        }
    }

    // MARK: - Prose

    private func proseView(lines: [String]) -> some View {
        Text(lines.joined(separator: "\n"))
            .font(.brewBody)
            .foregroundStyle(Color.brewTextSecondary)
            .textSelection(.enabled)
    }

    // MARK: - Caption (small prose above a UI element)

    @ViewBuilder
    private func captionText(_ caption: String?) -> some View {
        if let caption {
            Text(caption)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextSecondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Command

    private func commandView(block: DoctorBlock, steps: [DoctorFixStep]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            captionText(block.caption)
            if steps.contains(where: \.needsAdmin) {
                Label("Needs admin · runs in Terminal", systemImage: "lock.fill")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
            }
            CommandBlockView(commands: steps.map(\.displayCommand))
            if isPrimaryRunnable(block) {
                runFixControls
            }
        }
    }

    private func isPrimaryRunnable(_ block: DoctorBlock) -> Bool {
        item.primaryRunnableBlock?.id == block.id
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

    // MARK: - Data

    private func dataView(caption: String?, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            captionText(caption)
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(items, id: \.self) { affected in
                    Text(affected)
                        .font(.brewCode)
                        .foregroundStyle(Color.brewTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Link

    private func linkView(caption: String?, links: [DoctorLink]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            captionText(caption)
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(links) { link in
                    DoctorLinkRow(link: link)
                }
            }
        }
    }

    // MARK: - Raw output

    private var rawOutputSection: some View {
        CommandBlockView(command: item.rawBody, title: "Raw output", collapsible: true)
    }
}

// MARK: - Subviews

private struct DoctorSeverityBadge: View {
    let severity: DoctorSeverity

    var body: some View {
        Label(DoctorSeverityStyle.displayName(severity),
              systemImage: DoctorSeverityStyle.icon(severity))
            .font(.brewCaption.weight(.semibold))
            .foregroundStyle(DoctorSeverityStyle.foreground(severity))
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
            .background(DoctorSeverityStyle.background(severity), in: Capsule())
            .accessibilityLabel("Severity: \(DoctorSeverityStyle.displayName(severity))")
    }
}

private struct DoctorLinkRow: View {
    let link: DoctorLink

    var body: some View {
        switch link.role {
        case .action:
            Link(destination: link.url) {
                Label(link.url.absoluteString, systemImage: "arrow.up.right.square.fill")
                    .font(.brewCallout.weight(.semibold))
            }
        case .reference:
            Link(destination: link.url) {
                Label(link.url.absoluteString, systemImage: "doc.text")
                    .font(.brewCallout)
            }
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
        let viewModel = DoctorViewModel(
            doctorRepository: PreviewSupport.makeDoctorRepository(report: report),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        Group {
            if let issue = report.issues.first {
                DoctorIssueDetailView(viewModel: viewModel, item: DoctorIssueItem(issue: issue))
            }
        }
        .frame(width: 380, height: 600)
    }
#endif
