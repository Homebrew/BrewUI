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
/// Walks the issue's parsed blocks in document order, rendering each as its own captioned section
/// (`.command` boxes, `.data` lists, `.link` lists, `.prose` text). Multi-group issues — currently only
/// `check_git_status`, where each dirty repo is its own subject — fall back to the verbatim raw-output
/// panel so a fix never gets orphaned from its files. Raw output stays at the bottom always as the
/// never-wrong fallback.
struct DoctorIssueDetailView: View {
    @Bindable var viewModel: DoctorViewModel
    let item: DoctorIssueItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                heroSection
                if item.requiresRawEscapeHatch {
                    escapeHatchSection
                } else if let group = item.groups.first, !group.isEmpty {
                    blocksSection(group)
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

    // MARK: - Escape hatch

    private var escapeHatchSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Label(
                "This warning has multiple subjects (one fix per item). Open the raw output below to see each.",
                systemImage: "info.circle",
            )
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextSecondary)
        }
    }

    // MARK: - Blocks

    private func blocksSection(_ blocks: [DoctorBlock]) -> some View {
        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
            blockView(block, isFirstProse: isFirstProseBlock(blocks: blocks, index: index))
        }
    }

    private func isFirstProseBlock(blocks: [DoctorBlock], index: Int) -> Bool {
        guard blocks[index].type == .prose else {
            return false
        }
        return !blocks.prefix(index).contains { $0.type == .prose }
    }

    @ViewBuilder
    private func blockView(_ block: DoctorBlock, isFirstProse: Bool) -> some View {
        switch block.content {
        case let .prose(lines):
            proseBlockView(lines: lines, isFirstProse: isFirstProse)
        case let .command(steps):
            commandBlockView(block: block, steps: steps)
        case let .data(items):
            dataBlockView(block: block, items: items)
        case let .link(links):
            linkBlockView(block: block, links: links)
        }
    }

    private func proseBlockView(lines: [String], isFirstProse: Bool) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            if isFirstProse {
                PackageDetailSectionHeading(title: "What this means")
            }
            Text(lines.joined(separator: " "))
                .font(.brewBody)
                .foregroundStyle(Color.brewTextSecondary)
                .textSelection(.enabled)
            if isFirstProse, !item.inlineChips.isEmpty {
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

    private func dataBlockView(block: DoctorBlock, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: displayCaption(block.caption, fallback: "Affected"))
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

    private func commandBlockView(block: DoctorBlock, steps: [DoctorFixStep]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            PackageDetailSectionHeading(title: displayCaption(block.caption, fallback: "Suggested fix"))
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

    private func linkBlockView(block: DoctorBlock, links: [DoctorLink]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: displayCaption(block.caption, fallback: "Links"))
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(links) { link in
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

/// Strips a trailing `:` and sentence-cases the result so captions like `Run \`brew link\` on these:` read
/// cleanly as section headings. Falls back to `fallback` when the parser didn't capture an intro caption.
private func displayCaption(_ caption: String?, fallback: String) -> String {
    guard var text = caption else {
        return fallback
    }
    if text.hasSuffix(":") {
        text.removeLast()
    }
    if let first = text.first, first.isLowercase {
        text = first.uppercased() + text.dropFirst()
    }
    return text.isEmpty ? fallback : text
}

// MARK: - Subviews

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
