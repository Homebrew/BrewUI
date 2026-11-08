//
//  AIHousekeepingSheet.swift
//  BrewUIComponents
//

import BrewCore
import SwiftUI

/// Modal sheet presenting AI orphan package analysis, leaf detection, and disk space reclamation recommendations.
public struct AIHousekeepingSheet: View {
    public let report: AIHousekeepingReport
    public let onRunCommand: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    public init(
        report: AIHousekeepingReport,
        onRunCommand: ((String) -> Void)? = nil,
    ) {
        self.report = report
        self.onRunCommand = onRunCommand
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                    summaryCard
                    orphansSection
                    commandsSection
                }
                .padding(BrewSpacing.xl)
            }

            Divider()
            footer
        }
        .frame(minWidth: 540, idealWidth: 600, maxWidth: 700, minHeight: 480, idealHeight: 560)
        .background(Color.brewSurfaceElevated)
    }

    private var header: some View {
        HStack(spacing: BrewSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewBrandPrimary)
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text("AI Storage & Housekeeping Advisor", bundle: #bundle, comment: "Housekeeping sheet title")
                    .font(.brewTitle3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brewTextPrimary)
                Text("Scan and safely prune orphaned packages and unneeded dependencies.", bundle: #bundle, comment: "Housekeeping sheet subtitle")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer()
        }
        .padding(BrewSpacing.lg)
    }

    private var summaryCard: some View {
        HStack(spacing: BrewSpacing.lg) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Reclaimable Disk Space", bundle: #bundle, comment: "Housekeeping reclaimable space label")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                Text(verbatim: report.reclaimableEstimate)
                    .font(.brewTitle1)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brewBrandPrimary)
            }

            Spacer()

            Text(verbatim: report.summary)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(BrewSpacing.md)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private var orphansSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Detected Leaf Packages (\(report.orphanCandidates.count))", bundle: #bundle, comment: "Housekeeping detected leaves section header")
                .font(.brewSubheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextPrimary)

            if report.orphanCandidates.isEmpty {
                Text("No orphaned packages found. Your Homebrew environment is clean!", bundle: #bundle, comment: "Housekeeping empty state")
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
                    .padding(.vertical, BrewSpacing.md)
            } else {
                VStack(spacing: BrewSpacing.xs) {
                    ForEach(report.orphanCandidates) { candidate in
                        orphanRow(candidate)
                    }
                }
            }
        }
    }

    private func orphanRow(_ candidate: AIOrphanCandidate) -> some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                HStack(spacing: BrewSpacing.xs) {
                    Text(verbatim: candidate.packageName)
                        .font(.brewBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brewTextPrimary)

                    Text(verbatim: "v\(candidate.installedVersion)")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }

                Text(verbatim: candidate.reason)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }

            Spacer()

            safetyBadge(candidate.safetyLevel)
        }
        .padding(BrewSpacing.sm)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.sm, style: .continuous)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private func safetyBadge(_ level: AISafetyLevel) -> some View {
        let isSafe = level == .safeToPrune
        let color = isSafe ? Color.brewStatusSuccess : Color.brewStatusWarning
        return Text(verbatim: level.title)
            .font(.brewCaption)
            .fontWeight(.semibold)
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var commandsSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Cleanup Commands", bundle: #bundle, comment: "Housekeeping recommended commands section")
                .font(.brewSubheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextPrimary)

            ForEach(report.recommendedCommands, id: \.self) { cmd in
                HStack(spacing: BrewSpacing.sm) {
                    CommandBlockView(command: cmd)
                    if let onRunCommand, isSupportedCommand(cmd) {
                        Button {
                            onRunCommand(cmd)
                            dismiss()
                        } label: {
                            Text("Run", bundle: #bundle, comment: "AI run command button")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func isSupportedCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.first == "brew",
              !trimmed.contains(";"),
              !trimmed.contains("&&"),
              !trimmed.contains("|"),
              !trimmed.contains(">"),
              !trimmed.contains("<"),
              !trimmed.contains("sudo")
        else { return false }
        return true
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(String(localized: "Done", bundle: #bundle, comment: "Housekeeping sheet dismiss button")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(BrewSpacing.lg)
    }
}
